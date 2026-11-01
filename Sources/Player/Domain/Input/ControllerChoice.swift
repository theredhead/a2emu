import Foundation

/// A controller connection, identified independently of its potentially duplicated display name.
struct ControllerChoice: Equatable {
    let id: String
    let name: String
}
