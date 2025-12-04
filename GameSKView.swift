import UIKit
import SpriteKit

class GameSKView: SKView {

    // ----------------------------------------------------
    // MARK: - First Responder Setup
    // ----------------------------------------------------
    override var canBecomeFirstResponder: Bool { true }

    override func didMoveToWindow() {
        super.didMoveToWindow()

        print("🟧 GameSKView didMoveToWindow()")
        print("🟧 Becoming first responder…")

        DispatchQueue.main.async {      // Important: avoids race conditions
            self.becomeFirstResponder()
        }
    }

    // When a new scene is presented, ensure view remains responder
    override func presentScene(_ scene: SKScene?) {
        super.presentScene(scene)

        print("🟧 GameSKView presented new scene → ensuring first responder")
        DispatchQueue.main.async {
            self.becomeFirstResponder()
        }
    }

    // ----------------------------------------------------
    // MARK: - KEY DOWN
    // ----------------------------------------------------
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {

        // Support multi-key input (e.g., run + jump)
        for press in presses {
            guard let key = press.key else { continue }

            let keyString = normalizeKey(key.charactersIgnoringModifiers)
            print("⬇️ Key Down: '\(keyString)'")

            (scene as? KeyboardControllable)?.handleKeyDown(keyString)
        }
    }

    // ----------------------------------------------------
    // MARK: - KEY UP
    // ----------------------------------------------------
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {

        for press in presses {
            guard let key = press.key else { continue }

            let keyString = normalizeKey(key.charactersIgnoringModifiers)
            print("⬆️ Key Up: '\(keyString)'")

            (scene as? KeyboardControllable)?.handleKeyUp(keyString)
        }
    }

    // ----------------------------------------------------
    // MARK: - KEY NORMALIZATION
    // ----------------------------------------------------
    private func normalizeKey(_ key: String?) -> String {
        guard let key = key else { return "" }

        // Convert to lowercase for consistency
        let lower = key.lowercased()

        switch lower {
        case " ":
            return " "                     // spacebar
        case "\r", "\n":
            return "enter"                // optional: unify enter key
        default:
            return lower
        }
    }
}
