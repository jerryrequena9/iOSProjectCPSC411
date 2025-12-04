import SpriteKit

class GameScene: SKScene, SKPhysicsContactDelegate, KeyboardControllable {

    // Player
    private var player: SKSpriteNode!

    // Movement state
    private var moveLeft = false
    private var moveRight = false
    private var isAttacking = false

    // Animations
    private var animations: [String: [SKTexture]] = [:]

    // Ground
    private var ground: SKSpriteNode!

    // Constants
    private let runSpeed: CGFloat = 250
    private let jumpForce: CGFloat = 350

    // ----------------------------------------------------
    // MARK: Scene Loaded
    // ----------------------------------------------------
    override func didMove(to view: SKView) {
        print("🟦 GameScene Loaded — Size:", size)

        physicsWorld.contactDelegate = self
        physicsWorld.gravity = CGVector(dx: 0, dy: -9.8)

        addBackground()
        addSignArrow()
        addMessage()

        setupWorldBounds()
        setupGround()
        loadAnimations()
        createPlayer()
    }

    // ----------------------------------------------------
    // MARK: Background
    // ----------------------------------------------------
    private func addBackground() {
        let tex = SKTexture(imageNamed: "BG")
        let bg = SKSpriteNode(texture: tex)
        bg.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bg.size = size
        bg.zPosition = -100
        addChild(bg)
    }

    // ----------------------------------------------------
    // MARK: UI
    // ----------------------------------------------------
    private func addSignArrow() {
        let arrow = SKSpriteNode(imageNamed: "SignArrow")
        arrow.position = CGPoint(
            x: size.width * 0.85,
            y: (ground?.position.y ?? 80) + 50
        )
        arrow.zPosition = 10
        addChild(arrow)
    }

    private func addMessage() {
        let label = SKLabelNode(text: "→ Walk to the right edge to enter Level 1")
        label.fontName = "AvenirNext-Bold"
        label.fontColor = .white
        label.fontSize = size.width * 0.03
        label.position = CGPoint(x: size.width * 0.5, y: size.height * 0.15)
        label.zPosition = 50
        addChild(label)
    }

    // ----------------------------------------------------
    // MARK: World Boundary
    // ----------------------------------------------------
    private func setupWorldBounds() {
        physicsBody = SKPhysicsBody(edgeLoopFrom: frame)
    }

    // ----------------------------------------------------
    // MARK: Ground
    // ----------------------------------------------------
    private func setupGround() {
        let height = size.height * 0.12
        ground = SKSpriteNode(color: .brown, size: CGSize(width: size.width, height: height))
        ground.position = CGPoint(x: size.width / 2, y: height / 2)

        ground.physicsBody = SKPhysicsBody(rectangleOf: ground.size)
        ground.physicsBody?.isDynamic = false

        addChild(ground)
    }

    // ----------------------------------------------------
    // MARK: Animations
    // ----------------------------------------------------
    private func loadAnimations() {
        let names = ["Idle", "Walk", "Jump", "Attack"]

        for name in names {
            var frames: [SKTexture] = []
            for i in 1...10 {
                let tex = SKTexture(imageNamed: "\(name) (\(i))")
                if tex.size().width > 0 { frames.append(tex) }
            }
            animations[name] = frames
        }
    }

    // ----------------------------------------------------
    // MARK: Player
    // ----------------------------------------------------
    private func createPlayer() {
        guard let idle = animations["Idle"]?.first else { return }

        player = SKSpriteNode(texture: idle)
        let scale = (size.width * 0.15) / idle.size().width
        player.setScale(scale)

        player.position = CGPoint(
            x: size.width * 0.3,
            y: ground.position.y + idle.size().height * scale * 0.4
        )

        let hitbox = CGSize(width: player.size.width * 0.6, height: player.size.height * 0.9)
        player.physicsBody = SKPhysicsBody(rectangleOf: hitbox)
        player.physicsBody?.allowsRotation = false

        addChild(player)
        playLoop("Idle")
    }

    // ----------------------------------------------------
    // MARK: Update Loop
    // ----------------------------------------------------
    override func update(_ currentTime: TimeInterval) {
        guard let body = player.physicsBody else { return }

        // movement
        if moveLeft {
            body.velocity.dx = -runSpeed
            player.xScale = -abs(player.xScale)
            playLoop("Walk")
        }
        else if moveRight {
            body.velocity.dx = runSpeed
            player.xScale = abs(player.xScale)
            playLoop("Walk")
        }
        else {
            body.velocity.dx = 0
            if !isAttacking { playLoop("Idle") }
        }

        // Transition check
        let triggerX = size.width - player.size.width / 2
        if player.position.x >= triggerX { goToLevel1() }
    }

    // ----------------------------------------------------
    // MARK: Transition
    // ----------------------------------------------------
    private func goToLevel1() {
        let next = Level1Scene(size: size)
        next.scaleMode = .resizeFill
        view?.presentScene(next, transition: .fade(withDuration: 1.0))
    }

    // ----------------------------------------------------
    // MARK: Animation Helpers
    // ----------------------------------------------------
    private func playLoop(_ name: String) {
        guard let frames = animations[name] else { return }

        if player.action(forKey: "anim") != nil,
            player.userData?["state"] as? String == name { return }

        player.removeAction(forKey: "anim")
        let action = SKAction.repeatForever(SKAction.animate(with: frames, timePerFrame: 0.06))

        if player.userData == nil { player.userData = [:] }
        player.userData!["state"] = name

        player.run(action, withKey: "anim")
    }

    private func playOnce(_ name: String) {
        isAttacking = true
        guard let frames = animations[name] else { return }

        let anim = SKAction.animate(with: frames, timePerFrame: 0.05)
        let finish = SKAction.run {
            self.isAttacking = false
            self.playLoop("Idle")
        }

        player.run(SKAction.sequence([anim, finish]), withKey: "anim")
    }

    // ----------------------------------------------------
    // MARK: Controls
    // ----------------------------------------------------
    func handleKeyDown(_ key: String) {
        switch key {
        case "a": moveLeft = true
        case "d": moveRight = true
        case "w": jump()
        case " ": playOnce("Attack")
        default: break
        }
    }

    func handleKeyUp(_ key: String) {
        switch key {
        case "a": moveLeft = false
        case "d": moveRight = false
        default: break
        }
    }

    // ----------------------------------------------------
    // MARK: Jump
    // ----------------------------------------------------
    private func jump() {
        guard let body = player.physicsBody else { return }
        if abs(body.velocity.dy) < 5 {
            body.applyImpulse(CGVector(dx: 0, dy: jumpForce))
            playLoop("Jump")
        }
    }
}
