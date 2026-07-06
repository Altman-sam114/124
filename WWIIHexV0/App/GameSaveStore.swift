import Foundation

struct GameSaveStatus: Equatable {
    enum Severity: Equatable {
        case success
        case notice
        case failure
    }

    let severity: Severity
    let title: String
    let detail: String?

    var needsAttention: Bool {
        severity == .failure
    }

    var summary: String {
        if let detail, !detail.isEmpty {
            return "\(title)：\(detail)"
        }
        return title
    }

    static func success(_ title: String, detail: String? = nil) -> GameSaveStatus {
        GameSaveStatus(severity: .success, title: title, detail: detail)
    }

    static func notice(_ title: String, detail: String? = nil) -> GameSaveStatus {
        GameSaveStatus(severity: .notice, title: title, detail: detail)
    }

    static func failure(_ title: String, detail: String? = nil) -> GameSaveStatus {
        GameSaveStatus(severity: .failure, title: title, detail: detail)
    }
}

struct GameSaveStore {
    let saveURL: URL

    init(saveURL: URL = URL.documentsDirectory.appending(path: "WWIIHexV0-current-game.json")) {
        self.saveURL = saveURL
    }

    var hasSavedGame: Bool {
        FileManager.default.fileExists(atPath: saveURL.path)
    }

    func load() throws -> GameState {
        let data = try Data(contentsOf: saveURL)
        return try decoder.decode(GameState.self, from: data)
    }

    func save(_ state: GameState) throws {
        let data = try encoder.encode(state)
        try data.write(to: saveURL, options: [.atomic])
    }

    func deleteSave() throws {
        guard hasSavedGame else {
            return
        }

        try FileManager.default.removeItem(at: saveURL)
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private var decoder: JSONDecoder {
        JSONDecoder()
    }
}
