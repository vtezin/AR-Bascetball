//
//  ViewController.swift
//  AR Bascetball
//
//  Created by test on 24/05/2019.
//  Copyright © 2019 test. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet var labelGoals: UILabel!
    
    // Counts vertical planes
    private var planeCounter = 0
    
    // True when hoop placed
    private var isHoopPlaced = false
    
    // True when vertical plane founded
    private var verticalPlaneIsFounded = false
    
    // index of current abgry bird
    private var indexOfCurrentBird = 0
    
    // count of goals
    private var countOfGoals = 0
    
    // count of used balls
    private var usedBalls = 0
    
    // radius of ball
    private var ballRadius:Float = 0.25
    
    private var currentState: applicationStates = .foundingPlates
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        sceneView.scene.physicsWorld.contactDelegate = self
        
        refreshResultLabel()
        // Show statistics such as fps and timing information
        // sceneView.showsStatistics = true
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Allow vertical plane detection
        configuration.planeDetection = [.vertical]
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }

}

// MARK: - Collisions of bodies
extension ViewController: SCNPhysicsContactDelegate {
    
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact){
        
        if contact.nodeB.name == "Ball" && contact.nodeA.name == "checkPointCenterOfCircle" {
            contact.nodeB.name = "ballFromCircle"
        }
        
        if contact.nodeB.name == "ballFromCircle" && contact.nodeA.name == "checkPointDown" {
            contact.nodeB.name = "ball"
            self.countOfGoals += 1
        }
        
        //print("\(contact.nodeA.name ?? "") -> \(contact.nodeB.name ?? "")")
        //DispatchQueue.main.async {
            self.refreshResultLabel()
        //}
        
    }
    
}

// MARK: - Custom Methods
extension ViewController {
    
    /// Refreshing of result info
    func refreshResultLabel() {
        
        let stateText: String
        
        switch currentState {
        case .foundingPlates:
            stateText = "...founding vertical plates"
        case .placingHoop:
            stateText = "place the hoop (tap on the plate)"
        case .game:
            stateText = "goals \(self.countOfGoals) | \(self.usedBalls) balls"
        }
        
        DispatchQueue.main.async {
            self.labelGoals.text = stateText
        }
    }
    
    /// Adding hoop
    ///
    /// - Parameter result: ArHitTestResult
    func addHoop(at result: ARHitTestResult) {
        
        let hoopScene = SCNScene(named: "art.scnassets/Hoop.scn")
        
        guard let hoopNode = hoopScene?.rootNode.childNode(withName: "Hoop", recursively: false) else { return }
        
        backboardTexture: if let backboardImage = UIImage(named: "art.scnassets/backboard.jpeg") {
            guard let backboardNode = hoopNode.childNode(withName: "backboard", recursively: false) else {
                break backboardTexture
            }
            guard let backboard = backboardNode.geometry as? SCNBox else { break backboardTexture }
            
            backboard.firstMaterial?.diffuse.contents = backboardImage
            
            hoopNode.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(
                node: hoopNode, options: [SCNPhysicsShape.Option.type: SCNPhysicsShape.ShapeType.concavePolyhedron]
            ))
            
            hoopNode.name = "Hoop"
        }
        
        // found ring position
        guard let ringNode = hoopNode.childNode(withName: "ring", recursively: false) else {return}
        let ringPosition = ringNode.position
        
        // Add contact 1 to the scene
        let checkPointUp = createCheckPoint()
        checkPointUp.name = "checkPointCenterOfCircle"
        hoopNode.addChildNode(checkPointUp)
        hoopNode.childNode(withName: "checkPointCenterOfCircle", recursively: false)?.position = SCNVector3(ringPosition.x, ringPosition.y + ballRadius, ringPosition.z)
        
        // Add contact 2 to the scene
        let checkPointDown = createCheckPoint()
        checkPointDown.name = "checkPointDown"
        hoopNode.addChildNode(checkPointDown)
        hoopNode.childNode(withName: "checkPointDown", recursively: false)?.position = SCNVector3(ringPosition.x, ringPosition.y - 1.5 * ballRadius, ringPosition.z)
        
        // Place the hoop in correct position
        
        hoopNode.simdTransform = result.worldTransform
        hoopNode.eulerAngles.x -= .pi/2
        
        // Remove all walls
        
        sceneView.scene.rootNode.enumerateChildNodes { node, _ in
            if node.name == "Wall" {
              node.removeFromParentNode()
            }
        }
        
        // Add the hoop to the scene
        sceneView.scene.rootNode.addChildNode(hoopNode)
        
        isHoopPlaced = true
    }
    
    /// Creating invisible check-point for recognize fact of goal
    ///
    /// - Returns: SCNNode of check point - small sphere
    func createCheckPoint() -> SCNNode {
        
        let checkPoint = SCNNode(geometry: SCNSphere(radius: 0.01))
        checkPoint.geometry?.firstMaterial?.diffuse.contents = UIColor.orange
        checkPoint.opacity = 0
        
        let body = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(node: checkPoint))
        checkPoint.physicsBody = body
        checkPoint.physicsBody?.categoryBitMask = 000000011
        checkPoint.physicsBody?.collisionBitMask = 000000100
        checkPoint.physicsBody?.contactTestBitMask = 00000010
        
        return checkPoint
    }
    
    /// Creating basket ball
    func createBasketball() {
        
        guard let frame = sceneView.session.currentFrame else { return }
        
        let ball = SCNNode(geometry: SCNSphere(radius: CGFloat(ballRadius)))
        
        if let birdImage = getNextBirdImage() {
           ball.geometry?.firstMaterial?.diffuse.contents = birdImage
        }
        
        let cameraTransform = SCNMatrix4(frame.camera.transform)
        ball.transform = cameraTransform
        
        let physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(node: ball))
        ball.physicsBody = physicsBody
        let power = Float(10)
        let x = -cameraTransform.m31 * power
        let y = -cameraTransform.m32 * power
        let z = -cameraTransform.m33 * power
        let force = SCNVector3(x, y, z)
        ball.physicsBody?.applyForce(force, asImpulse: true)
        ball.physicsBody?.categoryBitMask = 00000010
        ball.name = "Ball"
        
        sceneView.scene.rootNode.addChildNode(ball)
        
    }
    
    /// Getting next of order bird image
    ///
    /// - Returns: image of next bird
    func getNextBirdImage()->UIImage? {
        
        let numberOfBirds = 4
        indexOfCurrentBird = (indexOfCurrentBird >= numberOfBirds - 1) ? 0 : indexOfCurrentBird + 1
        
        return UIImage(named: "textureAngrybird\(indexOfCurrentBird)")
        
    }
    
}

// MARK: - IBActions
extension ViewController {
    
    @IBAction func screenTapped(_ sender: UITapGestureRecognizer) {
        
        if isHoopPlaced {
            createBasketball()
            usedBalls += 1
            self.refreshResultLabel()
        } else {
            let location = sender.location(in: sceneView)
            guard let result = sceneView.hitTest(location, types: [.existingPlaneUsingExtent]).first else { return }
            addHoop(at: result)
            currentState = .game
            refreshResultLabel()
        }
        
    }
}

// MARK: - ARSCNViewDelegate
extension ViewController: ARSCNViewDelegate {
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        
        guard !isHoopPlaced else { return }
        
        if !verticalPlaneIsFounded {
            currentState = .placingHoop
            refreshResultLabel()
        }

        guard let anchor = anchor as? ARPlaneAnchor else { return }
        
        let plane = SCNPlane(width: CGFloat(anchor.extent.x), height: CGFloat(anchor.extent.z))
        plane.firstMaterial?.diffuse.contents = UIColor.green
        
        let planeNode = SCNNode(geometry: plane)
        
        planeNode.eulerAngles.x = -.pi/2
        planeNode.name = "Wall"
        planeNode.opacity = 0.25
        
        node.addChildNode(planeNode)
        
        verticalPlaneIsFounded = true
        
    }
    
}
