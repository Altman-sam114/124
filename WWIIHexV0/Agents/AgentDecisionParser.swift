import Foundation

// DEPRECATED as of v0.352 - kept for regression reference, not invoked by default. See WarPipelineMode.
enum AgentDecisionParserError: Error, Equatable, LocalizedError {
    case malformedJSON(String)
    case unsupportedSchemaVersion(Int)
    case agentMismatch(expected: String, actual: String)
    case turnMismatch(expected: Int, actual: Int)
    case missingRegionDestination(divisionId: String)

    var errorDescription: String? {
        switch self {
        case .malformedJSON:
            return "朝堂决策原文无法解析。"
        case .unsupportedSchemaVersion(let version):
            return "朝堂决策格式版本 \(version) 暂不支持。"
        case .agentMismatch:
            return "朝堂决策来源不匹配。"
        case .turnMismatch(let expected, let actual):
            return "朝堂决策回合不匹配：预期第 \(expected) 回合，实际第 \(actual) 回合。"
        case .missingRegionDestination:
            return "行军命令缺少目标州郡。"
        }
    }
}

struct AgentDecisionParser {
    let supportedSchemaVersions: Set<Int>
    private let decoder: JSONDecoder

    init(supportedSchemaVersion: Int, decoder: JSONDecoder = JSONDecoder()) {
        self.supportedSchemaVersions = [supportedSchemaVersion]
        self.decoder = decoder
    }

    init(supportedSchemaVersions: Set<Int> = [1, 2], decoder: JSONDecoder = JSONDecoder()) {
        self.supportedSchemaVersions = supportedSchemaVersions
        self.decoder = decoder
    }

    func parse(
        _ rawJSON: String,
        expectedAgentId: String? = nil,
        expectedTurn: Int? = nil
    ) throws -> AgentDecisionEnvelope {
        guard let data = rawJSON.data(using: .utf8) else {
            throw AgentDecisionParserError.malformedJSON("输入内容不是有效 UTF-8。")
        }

        let envelope: AgentDecisionEnvelope
        do {
            envelope = try decoder.decode(AgentDecisionEnvelope.self, from: data)
        } catch {
            throw AgentDecisionParserError.malformedJSON(error.localizedDescription)
        }

        guard supportedSchemaVersions.contains(envelope.schemaVersion) else {
            throw AgentDecisionParserError.unsupportedSchemaVersion(envelope.schemaVersion)
        }

        if let expectedAgentId, envelope.agentId != expectedAgentId {
            throw AgentDecisionParserError.agentMismatch(expected: expectedAgentId, actual: envelope.agentId)
        }

        if let expectedTurn, envelope.turn != expectedTurn {
            throw AgentDecisionParserError.turnMismatch(expected: expectedTurn, actual: envelope.turn)
        }

        if envelope.schemaVersion >= 2 {
            for order in envelope.orders where order.type == .move && order.toRegionId == nil {
                throw AgentDecisionParserError.missingRegionDestination(divisionId: order.divisionId)
            }
        }

        return envelope
    }
}
