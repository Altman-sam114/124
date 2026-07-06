import Foundation

struct CommandResultSummary: Identifiable, Codable, Equatable {
    let id: String
    let orderIndex: Int?
    let divisionId: String?
    let orderType: AgentOrderType?
    let commandKind: CommandSummaryKind?
    let commandDisplayName: String?
    let mappingSucceeded: Bool
    let validationSucceeded: Bool?
    let executed: Bool
    let message: String
    let errors: [String]

    init(
        id: String,
        orderIndex: Int?,
        divisionId: String?,
        orderType: AgentOrderType?,
        commandKind: CommandSummaryKind?,
        commandDisplayName: String?,
        mappingSucceeded: Bool,
        validationSucceeded: Bool?,
        executed: Bool,
        message: String,
        errors: [String]
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.divisionId = divisionId
        self.orderType = orderType
        self.commandKind = commandKind
        self.commandDisplayName = commandDisplayName
        self.mappingSucceeded = mappingSucceeded
        self.validationSucceeded = validationSucceeded
        self.executed = executed
        self.message = message
        self.errors = errors
    }

    static func mapped(
        orderIndex: Int,
        order: AgentOrder,
        command: Command,
        result: CommandResult
    ) -> CommandResultSummary {
        CommandResultSummary(
            id: "order_\(orderIndex)_\(order.divisionId)_\(order.type.rawValue)",
            orderIndex: orderIndex,
            divisionId: order.divisionId,
            orderType: order.type,
            commandKind: CommandSummaryKind(command),
            commandDisplayName: command.displayName,
            mappingSucceeded: true,
            validationSucceeded: result.validation.isValid,
            executed: result.succeeded,
            message: result.message,
            errors: result.validation.errors.map(\.displayName)
        )
    }

    static func mappingFailed(
        orderIndex: Int,
        order: AgentOrder,
        error: Error
    ) -> CommandResultSummary {
        CommandResultSummary(
            id: "order_\(orderIndex)_\(order.divisionId)_mapping_failed",
            orderIndex: orderIndex,
            divisionId: order.divisionId,
            orderType: order.type,
            commandKind: nil,
            commandDisplayName: nil,
            mappingSucceeded: false,
            validationSucceeded: nil,
            executed: false,
            message: "军令转换失败。",
            errors: [mappingErrorDescription(error)]
        )
    }

    static func endTurn(result: CommandResult) -> CommandResultSummary {
        CommandResultSummary(
            id: "end_turn",
            orderIndex: nil,
            divisionId: nil,
            orderType: nil,
            commandKind: .endTurn,
            commandDisplayName: Command.endTurn.displayName,
            mappingSucceeded: true,
            validationSucceeded: result.validation.isValid,
            executed: result.succeeded,
            message: result.message,
            errors: result.validation.errors.map(\.displayName)
        )
    }

    static func directiveCommand(
        directiveIndex: Int,
        commandIndex: Int,
        directive: ZoneDirective,
        command: Command,
        result: CommandResult
    ) -> CommandResultSummary {
        CommandResultSummary(
            id: "directive_\(directiveIndex)_command_\(commandIndex)_\(directive.type.rawValue)",
            orderIndex: commandIndex,
            divisionId: command.actingDivisionId,
            orderType: nil,
            commandKind: CommandSummaryKind(command),
            commandDisplayName: command.displayName,
            mappingSucceeded: true,
            validationSucceeded: result.validation.isValid,
            executed: result.succeeded,
            message: result.message,
            errors: result.validation.errors.map(\.displayName)
        )
    }

    static func systemCommand(
        idPrefix: String,
        commandIndex: Int,
        command: Command,
        result: CommandResult
    ) -> CommandResultSummary {
        CommandResultSummary(
            id: "\(idPrefix)_command_\(commandIndex)",
            orderIndex: commandIndex,
            divisionId: command.actingDivisionId,
            orderType: nil,
            commandKind: CommandSummaryKind(command),
            commandDisplayName: command.displayName,
            mappingSucceeded: true,
            validationSucceeded: result.validation.isValid,
            executed: result.succeeded,
            message: result.message,
            errors: result.validation.errors.map(\.displayName)
        )
    }

    private static func mappingErrorDescription(_ error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           !description.isEmpty {
            return description
        }
        return "军令转换失败，无法匹配当前战局。"
    }
}

extension CommandResultSummary {
    private enum CodingKeys: String, CodingKey {
        case id
        case orderIndex
        case divisionId
        case orderType
        case commandKind
        case commandDisplayName
        case mappingSucceeded
        case validationSucceeded
        case executed
        case message
        case errors
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            orderIndex: try container.decodeIfPresent(Int.self, forKey: .orderIndex),
            divisionId: try container.decodeIfPresent(String.self, forKey: .divisionId),
            orderType: try container.decodeIfPresent(AgentOrderType.self, forKey: .orderType),
            commandKind: try container.decodeIfPresent(CommandSummaryKind.self, forKey: .commandKind),
            commandDisplayName: try container.decodeIfPresent(String.self, forKey: .commandDisplayName),
            mappingSucceeded: try container.decode(Bool.self, forKey: .mappingSucceeded),
            validationSucceeded: try container.decodeIfPresent(Bool.self, forKey: .validationSucceeded),
            executed: try container.decode(Bool.self, forKey: .executed),
            message: try container.decode(String.self, forKey: .message),
            errors: try container.decode([String].self, forKey: .errors)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(orderIndex, forKey: .orderIndex)
        try container.encodeIfPresent(divisionId, forKey: .divisionId)
        try container.encodeIfPresent(orderType, forKey: .orderType)
        try container.encodeIfPresent(commandKind, forKey: .commandKind)
        try container.encodeIfPresent(commandDisplayName, forKey: .commandDisplayName)
        try container.encode(mappingSucceeded, forKey: .mappingSucceeded)
        try container.encodeIfPresent(validationSucceeded, forKey: .validationSucceeded)
        try container.encode(executed, forKey: .executed)
        try container.encode(message, forKey: .message)
        try container.encode(errors, forKey: .errors)
    }
}

enum CommandSummaryKind: String, Codable, Equatable {
    case move
    case attack
    case hold
    case allowRetreat
    case resupply
    case queueProduction
    case governRegion
    case updateDiplomacy
    case resolveSubmissionHandoff
    case endTurn

    init(_ command: Command) {
        switch command {
        case .move:
            self = .move
        case .attack:
            self = .attack
        case .hold:
            self = .hold
        case .allowRetreat:
            self = .allowRetreat
        case .resupply:
            self = .resupply
        case .queueProduction:
            self = .queueProduction
        case .governRegion:
            self = .governRegion
        case .updateDiplomacy:
            self = .updateDiplomacy
        case .resolveSubmissionHandoff:
            self = .resolveSubmissionHandoff
        case .endTurn:
            self = .endTurn
        }
    }
}

struct AgentDecisionRecord: Identifiable, Codable, Equatable {
    let id: String
    let turn: Int
    let agentId: String
    let provider: String
    let contextSummary: String
    let rawJSON: String?
    let parsedIntent: String?
    let commandResults: [CommandResultSummary]
    let errors: [String]
}
