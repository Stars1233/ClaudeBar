import Foundation

// MARK: - Connection Result

public enum ConnectionResult: Equatable, Sendable {
    case success
    case failure(ConnectionError)
}

public enum ConnectionError: Equatable, Sendable {
    case invalidDirection
    case selfConnection
    case incompatibleTypes
    case alreadyConnected
    case noSourcePort
}

// MARK: - Connection Validator

/// Single responsibility: Validate if two ports can be connected
public struct ConnectionValidator {

    public init() {}

    /// Check if connection from source to target is valid
    public func validate(from source: Port, to target: Port, existingConnections: [FlowEdge]) -> ConnectionResult {
        // Rule 1: Must be output → input
        guard source.isOutput && target.isInput else {
            return .failure(.invalidDirection)
        }

        // Rule 2: Can't connect to same node
        guard let sourceNode = source.node,
              let targetNode = target.node,
              sourceNode.id != targetNode.id else {
            return .failure(.selfConnection)
        }

        // Rule 3: Types must be compatible
        guard source.dataType.isCompatible(with: target.dataType) else {
            return .failure(.incompatibleTypes)
        }

        // Rule 4: Can't already be connected
        let alreadyExists = existingConnections.contains { edge in
            edge.sourcePortId == source.id && edge.targetPortId == target.id
        }
        guard !alreadyExists else {
            return .failure(.alreadyConnected)
        }

        return .success
    }

    /// Quick check without error details (for UI highlighting)
    public func canConnect(from source: Port, to target: Port, existingConnections: [FlowEdge]) -> Bool {
        validate(from: source, to: target, existingConnections: existingConnections) == .success
    }
}
