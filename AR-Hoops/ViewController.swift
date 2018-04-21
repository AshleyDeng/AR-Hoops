//
//  ViewController.swift
//  AR-Hoops
//
//  Created by Dongcheng Deng on 2018-04-03.
//  Copyright © 2018 Showpass. All rights reserved.
//

import UIKit
import ARKit
import Each

class ViewController: UIViewController, ARSCNViewDelegate {
  
  @IBOutlet weak var planeDetected: UILabel!
  @IBOutlet weak var sceneView: ARSCNView!
  let configuration = ARWorldTrackingConfiguration()
  var power: Int = 1
  var basketAdded: Bool = false
  var timer = Each(0.05).seconds
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    sceneView.delegate = self
    
    configuration.planeDetection = .horizontal
    sceneView.debugOptions = [ARSCNDebugOptions.showWorldOrigin, ARSCNDebugOptions.showFeaturePoints]
    sceneView.session.run(configuration)
    sceneView.autoenablesDefaultLighting = true
    
    let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
    tapGestureRecognizer.cancelsTouchesInView = false
    sceneView.addGestureRecognizer(tapGestureRecognizer)
  }

  @objc func handleTap(sender: UITapGestureRecognizer) {
    guard let sceneView = sender.view as? ARSCNView else {return}
    let touchLocation = sender.location(in: sceneView)
    
    let hitTestResult = sceneView.hitTest(touchLocation, types: .existingPlaneUsingExtent)
    if !hitTestResult.isEmpty {
      addCourt(hitTestResult: hitTestResult.first!)
    }
  }
  
  func addCourt(hitTestResult: ARHitTestResult) {
    if basketAdded {
      return
    }
    
    let basketScene = SCNScene(named: "Basketball.scnassets/Basketball.scn")
    let basketNode = basketScene?.rootNode.childNode(withName: "Basket", recursively: false)
    basketNode?.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(node: basketNode!, options: [SCNPhysicsShape.Option.keepAsCompound: true, SCNPhysicsShape.Option.type: SCNPhysicsShape.ShapeType.concavePolyhedron]))
    
    let transform = hitTestResult.worldTransform
    let planeXposition = transform.columns.3.x
    let planeYposition = transform.columns.3.y
    let planeZposition = transform.columns.3.z
    
    basketNode?.position = SCNVector3(planeXposition, planeYposition, planeZposition)
    sceneView.scene.rootNode.addChildNode(basketNode!)
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      self.basketAdded = true
    }
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    if basketAdded {
      timer.perform(closure: { () -> NextStep in
        self.power += 1
        return .continue
      })
    }
  }
  
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    if basketAdded {
      timer.stop()
      shootBall()
    }
    power = 1
  }
  
  func shootBall() {
    guard let pointOfView = sceneView.pointOfView else { return }
    removeOtherBalls()
    
    let transform = pointOfView.transform
    let orientation = SCNVector3(-transform.m31, -transform.m32, -transform.m33)
    let location = SCNVector3(transform.m41, transform.m42, transform.m43)
    let position = location + orientation
    
    let ball = SCNNode(geometry: SCNSphere(radius: 0.25))
    ball.geometry?.firstMaterial?.diffuse.contents = #imageLiteral(resourceName: "ball")
    ball.position = position
    ball.name = "basketball"
    
    let body = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(node: ball))
    body.restitution = 0.2
    ball.physicsBody = body
    ball.physicsBody?.applyForce(SCNVector3(orientation.x * Float(power), orientation.y * Float(power), orientation.z * Float(power)), asImpulse: true)
    sceneView.scene.rootNode.addChildNode(ball)
  }
  
  func removeOtherBalls() {
    sceneView.scene.rootNode.enumerateChildNodes { (node, _) in
      if node.name == "basketball" {
        node.removeFromParentNode()
      }
    }
  }
  
  func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
    guard anchor is ARPlaneAnchor else { return }
    
    DispatchQueue.main.async {
      self.planeDetected.isHidden = false
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
      self.planeDetected.isHidden = true
    }
  }
  
  deinit {
    timer.stop()
  }
}

func +(left: SCNVector3, right: SCNVector3) -> SCNVector3 {
  return SCNVector3Make(left.x + right.x, left.y + right.y, left.z + right.z)
}
