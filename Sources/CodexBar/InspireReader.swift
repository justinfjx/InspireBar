import Foundation
import InspireBarCore

struct InspireReader: Sendable {
    enum Failure: LocalizedError {
        case missingCLI, missingReader, timeout, failed

        var errorDescription: String? {
            switch self {
            case .missingCLI: "需要 Inspire CLI。安装后，在终端运行 inspire login。"
            case .missingReader: "应用包缺少 Inspire 采集器，请重新构建。"
            case .timeout: "同步超时，稍后可再次刷新。"
            case .failed: "无法读取 Inspire。请检查 Inspire CLI 版本和登录状态。"
            }
        }
    }

    let directory: URL
    let importArchive: URL?
    var snapshotURL: URL {
        self.directory.appending(path: "snapshot.json")
    }

    func refresh() async throws -> InspireSnapshot {
        try await Task.detached(priority: .utility) { try self.readInspire() }.value
    }

    func readInspire() throws -> InspireSnapshot {
        let python = try Self.inspirePython()
        let resources = Bundle.main.url(forResource: "InspireBar_InspireBar", withExtension: "bundle")
            .flatMap(Bundle.init(url:)) ?? .module
        guard let reader = resources.url(forResource: "collect", withExtension: "py", subdirectory: "InspireReader")
        else { throw Failure.missingReader }

        let previous = (try? self.snapshotURL.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate
        let process = Process()
        process.executableURL = python
        process.arguments = ["-B", reader.path, "--runtime", self.directory.path]
        if let source = self.importArchive {
            process.arguments?.append(contentsOf: ["--import-archive", source.path])
        }
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        let complete = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in complete.signal() }
        try process.run()
        guard complete.wait(timeout: .now() + 180) == .success else {
            process.terminate()
            throw Failure.timeout
        }
        let updated = (try? self.snapshotURL.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate
        guard let updated, updated != previous, let result = try? InspireSnapshot.load(from: self.snapshotURL)
        else { throw Failure.failed }
        return result
    }

    private static func inspirePython() throws -> URL {
        let files = FileManager.default
        let home = files.homeDirectoryForCurrentUser
        let shellPath = ProcessInfo.processInfo.environment["PATH"]?.split(separator: ":").map(String.init) ?? []
        let locations = [home.appending(path: ".local/bin").path, "/opt/homebrew/bin", "/usr/local/bin"] + shellPath
        for location in locations where location.hasPrefix("/") {
            let cli = URL(fileURLWithPath: location).appending(path: "inspire").resolvingSymlinksInPath()
            let python = cli.deletingLastPathComponent().appending(path: "python")
            if files.isExecutableFile(atPath: cli.path), files.isExecutableFile(atPath: python.path) {
                return python
            }
        }
        throw Failure.missingCLI
    }
}
