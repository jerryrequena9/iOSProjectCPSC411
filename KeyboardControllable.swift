import SpriteKit

/// Any scene that wants to receive keyboard input must conform to this protocol.
/// NOTE:
/// This protocol *does not* read keys itself.
/// GameSKView intercepts keyboard events and forwards them here.
protocol KeyboardControllable: AnyObject {

    /// Called when a keyboard key is pressed.
    func handleKeyDown(_ key: String)

    /// Called when a keyboard key is released.
    func handleKeyUp(_ key: String)
}


// =============================================================
// MARK: - OPTIONAL DEBUGGING HELPERS + UTILITY METHODS
// =============================================================
extension KeyboardControllable where Self: SKScene {

    // ---------------------------------------------------------
    // MARK: Debug Logging
    // ---------------------------------------------------------
    func debugKeyDown(_ key: String) {
        print("🎹 [KeyDown] \(type(of: self)) → '\(key)'")
    }

    func debugKeyUp(_ key: String) {
        print("🎹 [KeyUp] \(type(of: self)) → '\(key)'")
    }

    // ---------------------------------------------------------
    // MARK: Key Categories
    // ---------------------------------------------------------
    var movementKeys: Set<String> { ["a", "d", "w"] }
    var actionKeys: Set<String> { [" ", "j"] }
    var debugKeys: Set<String> { ["1", "2", "9", "0"] } // optional

    /// Returns true if this key is for movement (walk, jump)
    func isMovementKey(_ key: String) -> Bool {
        return movementKeys.contains(key)
    }

    /// Returns true if this key triggers an attack or shield
    func isActionKey(_ key: String) -> Bool {
        return actionKeys.contains(key)
    }

    /// Optional: keys for debugging (scene switching, etc.)
    func isDebugKey(_ key: String) -> Bool {
        return debugKeys.contains(key)
    }

    // ---------------------------------------------------------
    // MARK: Input Blocking (Optional)
    // ---------------------------------------------------------
    /// Useful if you want to disable input while shielding or during cutscenes.
    func blockInput(reason: String) {
        print("⛔ Input blocked — \(reason)")
    }
}
