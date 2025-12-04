import SpriteKit

class Level1Scene: SKScene, SKPhysicsContactDelegate, KeyboardControllable {

    // ----------------------------------------------------
    // MARK: - Physics Categories
    // ----------------------------------------------------
    struct PhysicsCategory {
        static let none: UInt32        = 0
        static let player: UInt32      = 0b1
        static let robot: UInt32       = 0b10
        static let ground: UInt32      = 0b100
        static let shieldCrate: UInt32 = 0b1000
        static let bullet: UInt32      = 0b1_0000
    }

    // ----------------------------------------------------
    // MARK: - Nodes & State
    // ----------------------------------------------------
    private var player: SKSpriteNode!
    private var robot: SKSpriteNode!
    private var ground: SKSpriteNode!

    private var animations: [String: [SKTexture]] = [:]
    private var robotAnimations: [String: [SKTexture]] = [:]
    private var muzzleFrames: [SKTexture] = []
    private var bulletFrames: [SKTexture] = []

    // Movement / State
    private var moveLeft = false
    private var moveRight = false
    private var isAttacking = false
    private var isShielding = false
    private var shieldCooldown = false
    private var robotIsAttacking = false
    private var isGameOver = false

    // Health
    private let playerMaxHealth = 100
    private let robotMaxHealth = 150
    private var playerHealth = 100
    private var robotHealth = 150

    // Health Bars
    private var playerHealthBarBG: SKSpriteNode!
    private var playerHealthBarFill: SKSpriteNode!
    private var robotHealthBarBG: SKSpriteNode!
    private var robotHealthBarFill: SKSpriteNode!

    // Endgame UI
    private var endOverlay: SKSpriteNode?
    private var retryButton: SKLabelNode?

    // Constants
    private let runSpeed: CGFloat = 250
    private let jumpForce: CGFloat = 350

    // ----------------------------------------------------
    // MARK: - Scene Setup
    // ----------------------------------------------------
    override func didMove(to view: SKView) {
        physicsWorld.contactDelegate = self
        physicsWorld.gravity = CGVector(dx: 0, dy: -9.8)

        loadBackground()
        setupWorldBounds()
        setupGround()
        loadAnimations()
        loadRobotAnimations()
        loadProjectileAssets()
        createPlayer()
        spawnRobot()
        setupHealthBars()
        startRobotAI()

        print("🌟 Level1 Loaded — Size:", size)
    }

    // ----------------------------------------------------
    // MARK: - Background / World / Ground
    // ----------------------------------------------------
    private func loadBackground() {
        let tex = SKTexture(imageNamed: "BG")
        let bg = SKSpriteNode(texture: tex)
        bg.position = CGPoint(x: size.width/2, y: size.height/2)
        bg.size = size
        bg.zPosition = -100
        addChild(bg)
    }

    private func setupWorldBounds() {
        physicsBody = SKPhysicsBody(edgeLoopFrom: frame)
        physicsBody?.categoryBitMask = PhysicsCategory.ground
        physicsBody?.collisionBitMask = PhysicsCategory.player | PhysicsCategory.robot | PhysicsCategory.bullet
    }

    private func setupGround() {
        let h = size.height * 0.12
        ground = SKSpriteNode(color: .brown, size: CGSize(width: size.width, height: h))
        ground.position = CGPoint(x: size.width/2, y: h/2)

        ground.physicsBody = SKPhysicsBody(rectangleOf: ground.size)
        ground.physicsBody?.isDynamic = false
        ground.physicsBody?.categoryBitMask = PhysicsCategory.ground
        ground.physicsBody?.collisionBitMask = PhysicsCategory.player | PhysicsCategory.robot | PhysicsCategory.bullet

        addChild(ground)
    }

    // ----------------------------------------------------
    // MARK: - Player Animations (adds Dead)
    // ----------------------------------------------------
    private func loadAnimations() {
        let names = ["Idle", "Walk", "Jump", "Attack", "Dead"]

        for name in names {
            var frames: [SKTexture] = []
            for i in 1...10 {
                let texName = "\(name) (\(i))"
                let tex = SKTexture(imageNamed: texName)
                if tex.size().width > 0 { frames.append(tex) }
            }
            animations[name] = frames
            print("🎞 Loaded \(name): \(frames.count) frames")
        }
    }

    // ----------------------------------------------------
    // MARK: - Robot Animations
    // ----------------------------------------------------
    private func loadRobotAnimations() {
        let animSets = [
            "RobotIdle": 10,
            "RobotRun": 8,
            "RobotJump": 10,
            "RobotMelee": 8,
            "RobotShoot": 4,
            "RobotDead": 10
        ]

        for (name, count) in animSets {
            var frames: [SKTexture] = []
            for i in 1...count {
                let texName = "\(name) (\(i))"
                let tex = SKTexture(imageNamed: texName)
                if tex.size().width > 0 { frames.append(tex) }
            }
            robotAnimations[name] = frames
            print("🤖 Loaded \(name): \(frames.count) frames")
        }
    }

    // ----------------------------------------------------
    // MARK: - Projectile Assets (Muzzle + Bullet)
    // ----------------------------------------------------
    private func loadProjectileAssets() {
        muzzleFrames = []
        for i in 0...4 {
            let name = String(format: "RobotMuzzle_%03d", i)
            let tex = SKTexture(imageNamed: name)
            if tex.size().width > 0 { muzzleFrames.append(tex) }
        }

        bulletFrames = []
        for i in 0...4 {
            let name = String(format: "RobotBullet_%03d", i)
            let tex = SKTexture(imageNamed: name)
            if tex.size().width > 0 { bulletFrames.append(tex) }
        }

        print("🔫 Muzzle frames:", muzzleFrames.count, " Bullet frames:", bulletFrames.count)
    }

    // ----------------------------------------------------
    // MARK: - Player Setup
    // ----------------------------------------------------
    private func createPlayer() {
        guard let idle = animations["Idle"]?.first else { return }

        player = SKSpriteNode(texture: idle)
        let scale = (size.width * 0.15) / idle.size().width
        player.setScale(scale)

        player.position = CGPoint(
            x: size.width * 0.15,
            y: ground.position.y + idle.size().height * scale * 0.4
        )

        let hitbox = CGSize(width: player.size.width * 0.6, height: player.size.height * 0.9)
        let body = SKPhysicsBody(rectangleOf: hitbox)
        body.allowsRotation = false
        body.categoryBitMask = PhysicsCategory.player
        body.collisionBitMask = PhysicsCategory.ground | PhysicsCategory.shieldCrate
        body.contactTestBitMask = PhysicsCategory.robot | PhysicsCategory.bullet

        player.physicsBody = body

        addChild(player)
        playLoop("Idle")
    }

    // ----------------------------------------------------
    // MARK: - Robot Setup
    // ----------------------------------------------------
    private func spawnRobot() {
        guard let idle = robotAnimations["RobotIdle"]?.first else { return }

        robot = SKSpriteNode(texture: idle)
        let scale = (size.width * 0.15) / idle.size().width
        robot.setScale(scale)

        robot.position = CGPoint(
            x: size.width * 0.65,
            y: player.position.y
        )

        let hitbox = CGSize(width: robot.size.width * 0.6, height: robot.size.height * 0.9)
        let body = SKPhysicsBody(rectangleOf: hitbox)
        body.allowsRotation = false
        body.categoryBitMask = PhysicsCategory.robot
        body.collisionBitMask = PhysicsCategory.ground | PhysicsCategory.shieldCrate
        body.contactTestBitMask = PhysicsCategory.player

        robot.physicsBody = body

        addChild(robot)
        playRobotLoop("RobotIdle")
    }

    // ----------------------------------------------------
    // MARK: - Health Bars (Option B style)
    // ----------------------------------------------------
    private func setupHealthBars() {
        let barSize = CGSize(width: 80, height: 10)

        // Player bar
        playerHealthBarBG = SKSpriteNode(color: .red, size: barSize)
        playerHealthBarBG.zPosition = 200

        playerHealthBarFill = SKSpriteNode(color: .green, size: barSize)
        playerHealthBarFill.anchorPoint = CGPoint(x: 0.0, y: 0.5)
        playerHealthBarFill.position = CGPoint(x: -barSize.width/2, y: 0)
        playerHealthBarFill.zPosition = 201

        playerHealthBarBG.addChild(playerHealthBarFill)
        addChild(playerHealthBarBG)

        // Robot bar
        robotHealthBarBG = SKSpriteNode(color: .red, size: barSize)
        robotHealthBarBG.zPosition = 200

        robotHealthBarFill = SKSpriteNode(color: .green, size: barSize)
        robotHealthBarFill.anchorPoint = CGPoint(x: 0.0, y: 0.5)
        robotHealthBarFill.position = CGPoint(x: -barSize.width/2, y: 0)
        robotHealthBarFill.zPosition = 201

        robotHealthBarBG.addChild(robotHealthBarFill)
        addChild(robotHealthBarBG)

        updateHealthBars()
    }

    private func updateHealthBars() {
        let pRatio = max(0, CGFloat(playerHealth) / CGFloat(playerMaxHealth))
        let rRatio = max(0, CGFloat(robotHealth) / CGFloat(robotMaxHealth))

        playerHealthBarFill.xScale = pRatio
        robotHealthBarFill.xScale = rRatio
    }

    // ----------------------------------------------------
    // MARK: - Robot AI
    // ----------------------------------------------------
    private func startRobotAI() {
        let loop = SKAction.repeatForever(SKAction.sequence([
            SKAction.run { self.robotDecideAction() },
            SKAction.wait(forDuration: 1.5)
        ]))
        robot.run(loop)
    }

    private func robotDecideAction() {
        guard !robotIsAttacking, !isGameOver, robotHealth > 0 else { return }

        robot.xScale = player.position.x < robot.position.x ? -abs(robot.xScale) : abs(robot.xScale)

        let choice = Int.random(in: 1...4)

        switch choice {
        case 1: robotDashAttack()
        case 2: robotJumpAttack()
        case 3: robotRunTowardPlayer()
        case 4: robotShootBurst()
        default: playRobotLoop("RobotIdle")
        }
    }

    private func robotDashAttack() {
        guard robotHealth > 0 else { return }
        robotIsAttacking = true
        playRobotOnce("RobotMelee")

        let dir: CGFloat = player.position.x < robot.position.x ? -1 : 1
        let dash = SKAction.moveBy(x: 180 * dir, y: 0, duration: 0.35)

        let damage = SKAction.run { self.applyRobotMeleeDamage() }

        robot.run(SKAction.sequence([
            dash,
            damage,
            SKAction.run {
                self.robotIsAttacking = false
                self.playRobotLoop("RobotIdle")
            }
        ]))
    }

    private func robotJumpAttack() {
        guard robotHealth > 0 else { return }
        robotIsAttacking = true
        playRobotOnce("RobotJump")

        let jump = SKAction.moveBy(x: 0, y: 140, duration: 0.4)

        robot.run(SKAction.sequence([
            jump,
            SKAction.wait(forDuration: 0.2),
            SKAction.run {
                self.applyRobotMeleeDamage()
                self.robotIsAttacking = false
                self.playRobotLoop("RobotIdle")
            }
        ]))
    }

    private func robotRunTowardPlayer() {
        guard robotHealth > 0 else { return }
        playRobotLoop("RobotRun")

        let dir: CGFloat = player.position.x < robot.position.x ? -1 : 1
        let move = SKAction.moveBy(x: 100 * dir, y: 0, duration: 0.5)

        robot.run(move) {
            self.playRobotLoop("RobotIdle")
        }
    }

    // Robot rapid-fire shooting
    private func robotShootBurst() {
        guard robotHealth > 0, !robotIsAttacking else { return }
        robotIsAttacking = true

        playRobotLoop("RobotShoot")

        let shootDuration: TimeInterval = 2.0
        let fireAction = SKAction.run { self.spawnMuzzleAndBullet() }
        let fireLoop = SKAction.repeat(SKAction.sequence([
            fireAction,
            SKAction.wait(forDuration: 0.3)
        ]), count: Int(shootDuration / 0.3))

        robot.run(SKAction.sequence([
            fireLoop,
            SKAction.run {
                self.robotIsAttacking = false
                self.playRobotLoop("RobotIdle")
            }
        ]))
    }

    private func spawnMuzzleAndBullet() {
        guard !muzzleFrames.isEmpty, !bulletFrames.isEmpty else { return }
        guard robotHealth > 0, !isGameOver else { return }

        let facingRight = robot.xScale > 0
        let muzzleOffsetX: CGFloat = facingRight ? robot.size.width * 0.4 : -robot.size.width * 0.4
        let muzzlePosition = CGPoint(
            x: robot.position.x + muzzleOffsetX,
            y: robot.position.y + robot.size.height * 0.1
        )

        // Muzzle
        let muzzle = SKSpriteNode(texture: muzzleFrames.first)
        muzzle.position = muzzlePosition
        muzzle.zPosition = robot.zPosition + 1
        muzzle.xScale = facingRight ? abs(muzzle.xScale) : -abs(muzzle.xScale)
        addChild(muzzle)

        let muzzleAnim = SKAction.animate(with: muzzleFrames, timePerFrame: 0.03)
        muzzle.run(SKAction.sequence([muzzleAnim, SKAction.removeFromParent()]))

        // Bullet
        let bullet = SKSpriteNode(texture: bulletFrames.first)
        bullet.position = muzzlePosition
        bullet.zPosition = robot.zPosition

        let radius = max(bullet.size.width, bullet.size.height) / 2
        let body = SKPhysicsBody(circleOfRadius: radius)
        body.categoryBitMask = PhysicsCategory.bullet
        body.collisionBitMask = PhysicsCategory.ground | PhysicsCategory.shieldCrate
        body.contactTestBitMask = PhysicsCategory.player | PhysicsCategory.shieldCrate | PhysicsCategory.ground
        body.affectedByGravity = false
        body.allowsRotation = false

        bullet.physicsBody = body

        addChild(bullet)

        let bulletAnim = SKAction.repeatForever(
            SKAction.animate(with: bulletFrames, timePerFrame: 0.04)
        )
        bullet.run(bulletAnim, withKey: "bulletAnim")

        let dx: CGFloat = facingRight ? 600 : -600
        let move = SKAction.moveBy(x: dx, y: 0, duration: 1.0)
        bullet.run(SKAction.sequence([move, SKAction.removeFromParent()]))
    }

    // ----------------------------------------------------
    // MARK: - Update Loop
    // ----------------------------------------------------
    override func update(_ currentTime: TimeInterval) {
        if isGameOver { return }

        // Follow player & robot with health bars
        if let player = player {
            playerHealthBarBG.position = CGPoint(
                x: player.position.x,
                y: player.position.y + player.size.height/2 + 20
            )
        }

        if let robot = robot {
            robotHealthBarBG.position = CGPoint(
                x: robot.position.x,
                y: robot.position.y + robot.size.height/2 + 20
            )
        }

        guard let body = player.physicsBody else { return }

        if isShielding {
            body.velocity.dx = 0
            return
        }

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
    }

    // ----------------------------------------------------
    // MARK: - Player Animations
    // ----------------------------------------------------
    private func playLoop(_ name: String) {
        guard let frames = animations[name] else { return }

        if player.action(forKey: "anim") != nil,
           player.userData?["state"] as? String == name {
            return
        }

        player.removeAction(forKey: "anim")

        let action = SKAction.repeatForever(
            SKAction.animate(with: frames, timePerFrame: 0.06)
        )

        if player.userData == nil { player.userData = [:] }
        player.userData!["state"] = name

        player.run(action, withKey: "anim")
    }

    private func playOnce(_ name: String) {
        isAttacking = true
        guard let frames = animations[name] else { return }

        player.removeAction(forKey: "anim")

        let anim = SKAction.animate(with: frames, timePerFrame: 0.05)

        // Hit occurs halfway through animation
        let damageTime = SKAction.sequence([
            SKAction.wait(forDuration: Double(frames.count) * 0.05 * 0.5),
            SKAction.run { self.applyPlayerMeleeDamage() }
        ])

        let group = SKAction.group([anim, damageTime])

        let finish = SKAction.run {
            self.isAttacking = false
            if !self.isShielding { self.playLoop("Idle") }
        }

        player.run(SKAction.sequence([group, finish]), withKey: "anim")
    }

    // ----------------------------------------------------
    // MARK: - Robot Animations
    // ----------------------------------------------------
    private func playRobotLoop(_ name: String) {
        guard let frames = robotAnimations[name] else { return }

        robot.removeAction(forKey: "robotAnim")

        let action = SKAction.repeatForever(
            SKAction.animate(with: frames, timePerFrame: 0.08)
        )

        robot.run(action, withKey: "robotAnim")
    }

    private func playRobotOnce(_ name: String) {
        guard let frames = robotAnimations[name] else { return }

        robot.removeAction(forKey: "robotAnim")
        let anim = SKAction.animate(with: frames, timePerFrame: 0.06)
        robot.run(anim, withKey: "robotAnim")
    }

    // ----------------------------------------------------
    // MARK: - Shield + Crate + Glow
    // ----------------------------------------------------
    private func activateShield() {
        guard !isShielding, !shieldCooldown, !isGameOver else { return }

        isShielding = true
        shieldCooldown = true

        // Freeze player on Idle frame
        if let idle = animations["Idle"]?.first {
            player.texture = idle
        }
        player.removeAction(forKey: "anim")

        // Crate
        let crate = SKSpriteNode(imageNamed: "Crate")
        crate.name = "shieldCrate"

        crate.position = CGPoint(
            x: player.position.x + (player.xScale > 0 ? 40 : -40),
            y: player.position.y - 20
        )

        crate.zPosition = player.zPosition - 1
        crate.setScale(1.0)

        let body = SKPhysicsBody(rectangleOf: crate.size)
        body.isDynamic = false
        body.affectedByGravity = false
        body.allowsRotation = false
        body.categoryBitMask = PhysicsCategory.shieldCrate
        body.collisionBitMask = PhysicsCategory.robot | PhysicsCategory.bullet
        body.contactTestBitMask = PhysicsCategory.bullet

        crate.physicsBody = body

        // Glow
        let glow = SKSpriteNode(color: .yellow,
                                size: CGSize(width: crate.size.width * 1.5,
                                             height: crate.size.height * 1.5))
        glow.alpha = 0.35
        glow.position = .zero
        glow.zPosition = -1
        glow.blendMode = .add
        crate.addChild(glow)

        let pulse = SKAction.repeatForever(SKAction.sequence([
            SKAction.scale(to: 1.15, duration: 0.4),
            SKAction.scale(to: 1.0, duration: 0.4)
        ]))
        crate.run(pulse)

        addChild(crate)

        // Timers
        run(SKAction.sequence([
            SKAction.wait(forDuration: 2.0),
            SKAction.run {
                crate.removeFromParent()
                self.isShielding = false
                self.playLoop("Idle")
            },
            SKAction.wait(forDuration: 2.0),
            SKAction.run {
                self.shieldCooldown = false
            }
        ]))
    }

    // ----------------------------------------------------
    // MARK: - Damage Helpers (with flash + numbers)
    // ----------------------------------------------------
    private func flash(node: SKSpriteNode) {
        let up = SKAction.colorize(with: .white, colorBlendFactor: 1.0, duration: 0.05)
        let down = SKAction.colorize(withColorBlendFactor: 0.0, duration: 0.1)
        node.run(SKAction.sequence([up, down]), withKey: "flash")
    }

    private func showDamage(_ amount: Int, at position: CGPoint, color: SKColor) {
        let label = SKLabelNode(text: "-\(amount)")
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 18
        label.fontColor = color
        label.position = position
        label.zPosition = 500

        addChild(label)

        let moveUp = SKAction.moveBy(x: 0, y: 40, duration: 0.6)
        let fadeOut = SKAction.fadeOut(withDuration: 0.6)
        let group = SKAction.group([moveUp, fadeOut])

        label.run(SKAction.sequence([group, SKAction.removeFromParent()]))
    }

    private func applyPlayerMeleeDamage() {
        guard robotHealth > 0, !isGameOver else { return }

        let dx = abs(player.position.x - robot.position.x)
        let dy = abs(player.position.y - robot.position.y)

        if dx < 120 && dy < 80 {
            let dmg = 20
            robotHealth -= dmg
            flash(node: robot)
            showDamage(dmg, at: CGPoint(x: robot.position.x, y: robot.position.y + robot.size.height/2), color: .red)
            print("🤜 Player hit robot! HP:", robotHealth)
            if robotHealth <= 0 {
                robotHealth = 0
                updateHealthBars()
                handleRobotDeath()
            } else {
                updateHealthBars()
            }
        }
    }

    private func applyRobotMeleeDamage() {
        guard playerHealth > 0, !isGameOver else { return }

        let dx = abs(player.position.x - robot.position.x)
        let dy = abs(player.position.y - robot.position.y)

        if dx < 120 && dy < 80 {
            let dmg = 15
            playerHealth -= dmg
            flash(node: player)
            showDamage(dmg, at: CGPoint(x: player.position.x, y: player.position.y + player.size.height/2), color: .red)
            print("🤖 Robot melee hit player! HP:", playerHealth)
            if playerHealth <= 0 {
                playerHealth = 0
                updateHealthBars()
                handlePlayerDeath()
            } else {
                updateHealthBars()
            }
        }
    }

    private func applyBulletHitPlayer() {
        guard playerHealth > 0, !isGameOver else { return }

        let dmg = 10
        playerHealth -= dmg
        flash(node: player)
        showDamage(dmg, at: CGPoint(x: player.position.x, y: player.position.y + player.size.height/2), color: .red)
        print("🔫 Bullet hit player! HP:", playerHealth)
        if playerHealth <= 0 {
            playerHealth = 0
            updateHealthBars()
            handlePlayerDeath()
        } else {
            updateHealthBars()
        }
    }

    // ----------------------------------------------------
    // MARK: - Death & End Game
    // ----------------------------------------------------
    private func handlePlayerDeath() {
        guard !isGameOver else { return }
        isGameOver = true

        player.removeAllActions()
        robot.removeAllActions()

        player.physicsBody?.velocity = .zero
        player.physicsBody?.isDynamic = false
        robot.physicsBody?.isDynamic = false

        if let deadFrames = animations["Dead"] {
            let death = SKAction.animate(with: deadFrames, timePerFrame: 0.08)
            player.run(death)
        }

        showEndGameOverlay(playerWon: false)
    }

    private func handleRobotDeath() {
        guard !isGameOver else { return }
        isGameOver = true

        player.removeAllActions()
        robot.removeAllActions()

        player.physicsBody?.velocity = .zero
        player.physicsBody?.isDynamic = false
        robot.physicsBody?.isDynamic = false

        if let deathFrames = robotAnimations["RobotDead"] {
            let death = SKAction.animate(with: deathFrames, timePerFrame: 0.08)
            robot.run(death)
        } else {
            robot.removeFromParent()
        }

        showEndGameOverlay(playerWon: true)
    }

    private func showEndGameOverlay(playerWon: Bool) {
        // Dim overlay
        let overlay = SKSpriteNode(color: SKColor.black.withAlphaComponent(0.6),
                                   size: self.size)
        overlay.position = CGPoint(x: size.width/2, y: size.height/2)
        overlay.zPosition = 800
        overlay.name = "endOverlay"

        addChild(overlay)
        endOverlay = overlay

        // Message
        let label = SKLabelNode(text: playerWon ? "Victory!" : "Game Over")
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 44
        label.fontColor = .white
        label.position = CGPoint(x: 0, y: 40)
        label.zPosition = 801

        overlay.addChild(label)

        // Retry button (simple minimal style)
        let retry = SKLabelNode(text: "Retry")
        retry.fontName = "AvenirNext-Medium"
        retry.fontSize = 28
        retry.fontColor = .white
        retry.position = CGPoint(x: 0, y: -20)
        retry.name = "retryButton"
        retry.zPosition = 801

        overlay.addChild(retry)
        retryButton = retry
    }

    // ----------------------------------------------------
    // MARK: - Physics Contacts
    // ----------------------------------------------------
    func didBegin(_ contact: SKPhysicsContact) {
        let a = contact.bodyA
        let b = contact.bodyB
        let mask = a.categoryBitMask | b.categoryBitMask

        // Bullet hits Player
        if mask == PhysicsCategory.bullet | PhysicsCategory.player {
            let bulletBody = a.categoryBitMask == PhysicsCategory.bullet ? a : b
            bulletBody.node?.removeFromParent()
            if !isShielding {   // shield blocks only by crate collisions
                applyBulletHitPlayer()
            }
        }

        // Bullet hits ShieldCrate
        if mask == PhysicsCategory.bullet | PhysicsCategory.shieldCrate {
            let bulletBody = a.categoryBitMask == PhysicsCategory.bullet ? a : b
            bulletBody.node?.removeFromParent()
            print("🛡 Bullet blocked by crate")
        }

        // Bullet hits ground / world bounds
        if mask == PhysicsCategory.bullet | PhysicsCategory.ground {
            let bulletBody = a.categoryBitMask == PhysicsCategory.bullet ? a : b
            bulletBody.node?.removeFromParent()
        }
    }

    // ----------------------------------------------------
    // MARK: - Controls
    // ----------------------------------------------------
    func handleKeyDown(_ key: String) {
        guard !isGameOver else { return }

        switch key {
        case "a": moveLeft = true
        case "d": moveRight = true
        case "w": jump()
        case "j": activateShield()
        case " ": playOnce("Attack")
        default: break
        }
    }

    func handleKeyUp(_ key: String) {
        guard !isGameOver else { return }

        switch key {
        case "a": moveLeft = false
        case "d": moveRight = false
        default: break
        }
    }

    // ----------------------------------------------------
    // MARK: - Touches (Retry Button)
    // ----------------------------------------------------
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isGameOver, let touch = touches.first else { return }

        let location = touch.location(in: self)
        let nodesAtPoint = nodes(at: location)

        if nodesAtPoint.contains(where: { $0.name == "retryButton" }) {
            restartLevel()
        }
    }

    private func restartLevel() {
        let newScene = Level1Scene(size: self.size)
        newScene.scaleMode = self.scaleMode
        let transition = SKTransition.fade(withDuration: 1.0)
        self.view?.presentScene(newScene, transition: transition)
    }

    // ----------------------------------------------------
    // MARK: - Jump
    // ----------------------------------------------------
    private func jump() {
        guard let body = player.physicsBody else { return }
        if abs(body.velocity.dy) < 5 {
            body.applyImpulse(CGVector(dx: 0, dy: jumpForce))
            playLoop("Jump")
            print("🟢 Jump")
        }
    }
}
