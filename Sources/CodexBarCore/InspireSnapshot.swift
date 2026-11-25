import Foundation

package enum InspireQuota {
    package static let project = "公共科研项目"
    package static let allowance = 67200 // Hundredths of a point.
    package static let pollInterval: TimeInterval = 300
    package static let day: TimeInterval = 86400

    package static func isFresh(_ sample: Date, at now: Date, refreshInterval: TimeInterval) -> Bool {
        now.timeIntervalSince(sample) <= refreshInterval * 3
    }

    package static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600) ?? .gmt
        return calendar
    }()

    package static func window(at date: Date) -> DateInterval {
        let weekdayFromMonday = (self.calendar.component(.weekday, from: date) + 5) % 7
        let midnight = self.calendar.startOfDay(for: date)
        let monday = midnight.addingTimeInterval(10 * 3600 - Double(weekdayFromMonday) * self.day)
        return DateInterval(start: date < monday ? monday - 7 * self.day : monday, duration: 7 * self.day)
    }

    package static func points(_ cents: Int?) -> String {
        cents.map { (Double($0) / 100).formatted(.number.precision(.fractionLength(2))) } ?? "—"
    }

    package static func dateText(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = self.calendar
        formatter.timeZone = self.calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

    package static func countdown(until end: Date, at now: Date) -> String {
        let minutes = max(0, Int(ceil(end.timeIntervalSince(now) / 60)))
        if minutes >= 1440 { return "\(minutes / 1440)天\(minutes % 1440 / 60)时" }
        if minutes >= 60 { return "\(minutes / 60)时\(minutes % 60)分" }
        return "\(minutes)分"
    }
}

package struct InspireProject: Decodable, Identifiable, Sendable {
    package let name: String
    package let balance: Int?
    package let scope: String
    package var id: String {
        self.name
    }

    package var isPersonal: Bool {
        self.scope == "member"
    }
}

package struct InspireInstance: Decodable, Identifiable, Sendable {
    package struct Utilization: Identifiable, Sendable {
        package enum Resource: String, Sendable {
            case cpu = "CPU"
            case gpu = "GPU"
        }

        package enum Band: Sendable {
            case low, elevated, high

            fileprivate init(fraction: Double) {
                self = switch fraction {
                case ..<0.6: .low
                case ..<0.8: .elevated
                default: .high
                }
            }
        }

        package let id: Resource
        package let fraction: Double
        package var band: Band {
            Band(fraction: self.fraction)
        }

        fileprivate init?(_ resource: Resource, fraction: Double?) {
            guard let fraction, (0...1).contains(fraction) else { return nil }
            self.id = resource
            self.fraction = fraction
        }

        package var percentage: String {
            let style: FloatingPointFormatStyle<Double>.Percent = .percent.precision(.fractionLength(0...1))
            let rounded = (self.fraction * 1000).rounded() / 1000
            // Keep readings such as 59.98% from rounding into the next color band.
            let displayStyle = Band(fraction: rounded) == self.band ? style : style.rounded(rule: .down)
            return self.fraction.formatted(displayStyle)
        }
    }

    package let identifier: String?
    package let name: String
    package let project: String
    package let workspace: String
    package let cards: Int
    package let gpuType: String?
    /// Platform quote for the instance resources, before applying the submitted priority.
    package let rate: Double?
    package let priority: Int?
    package let priorityLevel: String?
    package let cpuUtilization: Double?
    package let gpuUtilization: Double?
    package var id: String {
        self.identifier ?? "\(self.project)/\(self.workspace)/\(self.name)"
    }

    package var billingRate: Double? {
        if let priority = self.priority, (1...3).contains(priority) { return 0 }
        return self.rate
    }

    package var utilization: [Utilization] {
        [
            Utilization(.cpu, fraction: self.cpuUtilization),
            Utilization(.gpu, fraction: self.gpuUtilization),
        ].compactMap(\.self)
    }

    package var cardLabel: String {
        let model = self.gpuType?.trimmingCharacters(in: .whitespacesAndNewlines)
        let knownModel = model.flatMap { $0.isEmpty ? nil : $0 }
        if self.cards > 0 {
            return "\(knownModel ?? "卡型未知") · \(self.cards) 卡"
        }
        return knownModel ?? "无 GPU"
    }

    package var priorityLabel: String {
        let level: String? = switch self.priorityLevel {
        case "LOW": "低"
        case "HIGH": "高"
        default: nil
        }
        if let priority = self.priority, (1...10).contains(priority) {
            return "优先级 \(priority)" + (level.map { "（\($0)）" } ?? "")
        }
        return level.map { "\($0)优先级" } ?? "优先级未知"
    }
}

package struct BalanceSample: Decodable, Equatable, Identifiable, Sendable {
    package let at: Date
    package let balance: Int
    package var id: Date {
        self.at
    }

    package init(at: Date, balance: Int) {
        self.at = at
        self.balance = balance
    }

    package init(from decoder: any Decoder) throws {
        var values = try decoder.unkeyedContainer()
        self.at = try Date(timeIntervalSince1970: values.decode(Double.self))
        self.balance = try values.decode(Int.self)
    }
}

package struct DailyCharge: Equatable, Identifiable, Sendable {
    package let date: Date
    package let amount: Int?
    package var id: Date {
        self.date
    }
}

package struct InspireSnapshot: Decodable, Sendable {
    package struct Latest: Decodable, Sendable {
        package let at: Date
        package let projects: [InspireProject]
        package let active: [InspireInstance]
        package let missingWorkspaces: [String]
    }

    struct Day: Decodable, Sendable {
        let spend: [String: Int]
    }

    struct Period: Decodable, Sendable {
        let start: Date
        let spend: [String: Int]
    }

    struct Billing: Decodable, Sendable {
        let at: Date
        let ranges: [String: [String: Int]]
        let cycle: Period
    }

    package let account: String?
    package let latest: Latest?
    package let samples: [BalanceSample]?
    package let collectionError: String?
    package let billingError: String?
    let days: [String: Day]?
    let billing: Billing?

    package static func load(from url: URL) throws -> Self {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(Self.self, from: Data(contentsOf: url))
    }

    package var publicProject: InspireProject? {
        self.latest?.projects.first { $0.name == InspireQuota.project && $0.isPersonal }
    }

    package var otherProjects: [InspireProject] {
        self.latest?.projects.filter { $0.name != InspireQuota.project } ?? []
    }

    package func isFresh(at now: Date, refreshInterval: TimeInterval = InspireQuota.pollInterval) -> Bool {
        guard let at = self.latest?.at else { return false }
        return InspireQuota.isFresh(at, at: now, refreshInterval: refreshInterval)
    }

    package func currentRate(
        project: String,
        at now: Date,
        refreshInterval: TimeInterval = InspireQuota.pollInterval)
        -> Double?
    {
        guard let latest = self.latest,
              latest.missingWorkspaces.isEmpty,
              self.isFresh(at: now, refreshInterval: refreshInterval)
        else {
            return nil
        }
        let rates = latest.active.filter { $0.project == project }.map(\.billingRate)
        guard rates.allSatisfy({ $0 != nil }) else { return nil }
        return rates.compactMap(\.self).reduce(0, +)
    }

    package func instanceList(project: String? = nil) -> [InspireInstance] {
        (self.latest?.active ?? []).filter { project == nil || $0.project == project }
    }

    package func cycleSpend(at now: Date) -> Int? {
        guard let cycle = self.billing?.cycle, cycle.start == InspireQuota.window(at: now).start else {
            return nil
        }
        return cycle.spend[InspireQuota.project]
    }

    package func billingTotal(project: String, dayCount: Int) -> Int? {
        self.billing?.ranges[String(dayCount)]?[project]
    }

    package func charges(project: String, dayCount: Int, at now: Date) -> [DailyCharge] {
        let calendar = InspireQuota.calendar
        let today = calendar.startOfDay(for: now)
        return (0..<dayCount).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let key = InspireQuota.dateText(date, format: "yyyy-MM-dd")
            return DailyCharge(date: date, amount: self.days?[key]?.spend[project])
        }
    }
}
