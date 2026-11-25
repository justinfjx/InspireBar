import Foundation
import Testing
@testable import InspireBarCore

struct InspireInstanceTests {
    @Test func `instance labels retain the actual card model project and priority`() throws {
        let row = try self.decode("""
        {
          "name":"demo-job","project":"公共科研项目","workspace":"GPU 测试空间",
          "cards":2,"gpu_type":"NVIDIA L40S (45GB)","priority":1,"priority_level":"LOW"
        }
        """)
        #expect(row.project == "公共科研项目")
        #expect(row.cardLabel == "NVIDIA L40S (45GB) · 2 卡")
        #expect(row.priorityLabel == "优先级 1（低）")
        #expect(row.rate == nil)
        #expect(row.billingRate == 0)
    }

    @Test func `old caches and unreported card types stay readable`() throws {
        let row = try self.decode("""
        {"name":"demo-job","project":"Project B","workspace":"GPU 测试空间","cards":1,"rate":0.33}
        """)
        #expect(row.cardLabel == "卡型未知 · 1 卡")
        #expect(row.priorityLabel == "优先级未知")
        #expect(row.billingRate == 0.33)
        #expect(row.utilization.isEmpty)
    }

    @Test func `a named priority is shown without displaying an internal score`() throws {
        let row = try self.decode("""
        {"name":"demo-job","project":"Project B","workspace":"GPU 测试空间","cards":1,
         "priority":11,"priority_level":"LOW"}
        """)
        #expect(row.priorityLabel == "低优先级")
    }

    @Test func `priority three is free and priority four uses the platform rate`() throws {
        let free = try self.decode("""
        {"name":"demo","project":"Project B","workspace":"GPU","cards":1,"rate":0.33,
         "priority":3,"cpu_utilization":0.128,"gpu_utilization":0}
        """)
        let paid = try self.decode("""
        {"name":"demo","project":"Project B","workspace":"GPU","cards":1,"rate":0.33,
         "priority":4,"priority_level":"LOW","cpu_utilization":0.128}
        """)
        let cpu = 0.128.formatted(.percent.precision(.fractionLength(0...1)))
        let gpu = 0.0.formatted(.percent.precision(.fractionLength(0...1)))
        #expect(free.billingRate == 0)
        #expect(free.utilization.map(\.id) == [.cpu, .gpu])
        #expect(free.utilization.map(\.percentage) == [cpu, gpu])
        #expect(paid.billingRate == 0.33)
        #expect(paid.utilization.map(\.id) == [.cpu])
        #expect(paid.utilization.map(\.percentage) == [cpu])
    }

    @Test func `CPU and GPU use independent bands at sixty and eighty percent`() throws {
        let below = try self.decode("""
        {"name":"demo","project":"Project B","workspace":"GPU","cards":1,
         "cpu_utilization":0.5999,"gpu_utilization":0.7999}
        """)
        let exact = try self.decode("""
        {"name":"demo","project":"Project B","workspace":"GPU","cards":1,
         "cpu_utilization":0.6,"gpu_utilization":0.8}
        """)
        let precision: FloatingPointFormatStyle<Double>.Percent = .percent.precision(.fractionLength(0...1))
        let belowLabels = [0.599, 0.799].map { $0.formatted(precision) }
        let exactLabels = [0.6, 0.8].map { $0.formatted(precision) }
        #expect(below.utilization.map(\.band) == [.low, .elevated])
        #expect(below.utilization.map(\.percentage) == belowLabels)
        #expect(exact.utilization.map(\.band) == [.elevated, .high])
        #expect(exact.utilization.map(\.percentage) == exactLabels)
    }

    @Test func `priority four leaves a missing platform rate unknown`() throws {
        let row = try self.decode("""
        {"name":"demo","project":"Project B","workspace":"GPU","cards":1,"priority":4}
        """)
        #expect(row.billingRate == nil)
    }

    private func decode(_ fixture: String) throws -> InspireInstance {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(InspireInstance.self, from: Data(fixture.utf8))
    }
}
