import UIKit
import SpriteKit

class GameViewController: UIViewController {

    private var scene: GameScene?

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        print("🔶 viewDidLayoutSubviews()")
        print(" - view.bounds =", view.bounds)

        // Ensure the view is your custom GameSKView
        guard let skView = view as? GameSKView else {
            print("❌ ERROR: View is not GameSKView — keyboard will NOT work.")
            return
        }

        let newSize = skView.bounds.size

        // ----------------------------------------------------
        // FIRST LOAD — Create GameScene
        // ----------------------------------------------------
        if scene == nil {
            print("🟩 Presenting GameScene with size:", newSize)

            let newScene = GameScene(size: newSize)
            newScene.scaleMode = .resizeFill

            scene = newScene
            skView.presentScene(newScene)

            skView.showsFPS = true
            skView.showsNodeCount = true
            skView.ignoresSiblingOrder = true

            // Ensure the SKView receives keyboard input
            DispatchQueue.main.async {
                skView.becomeFirstResponder()
            }

            return
        }

        // ----------------------------------------------------
        // ON ROTATION OR RESIZE — Update scene size
        // ----------------------------------------------------
        if scene!.size != newSize {
            print("📐 Scene resizing:", scene!.size, "→", newSize)
            scene!.size = newSize
            scene!.scaleMode = .resizeFill
        }

        // Ensure keyboard input stays active
        DispatchQueue.main.async {
            skView.becomeFirstResponder()
        }
    }

    // ----------------------------------------------------
    // MARK: Orientation
    // ----------------------------------------------------
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
