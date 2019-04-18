//
//  ViewController.swift
//  HearTheLIne
//
//  Created by Dreamy Sun on 4/17/19.
//  Copyright © 2019 ChenyuSun. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Foundation
import GLKit

class ViewController: UIViewController, ARSCNViewDelegate {
    
    var rootNode: SCNNode?
    var sessTool: Tool!
    var userIsDrawing = false
    var userIsMovingStructure = false
    var bufferNode: SCNNode?
    var selectionHolderNode: SCNNode?
    var newPointBuffer: [SCNNode]?
    var oldOrientation: SCNQuaternion?
    var worldUp: SCNVector4 {
        let wUp = rootNode!.worldUp
        let upVec = SCNVector4.init(wUp.x, wUp.y, wUp.z, 1.0)
        return upVec
    }
 
    @IBOutlet weak var icon: UIImageView!
    
    var recordicon = UIImage(named:"recordicon.png")

    
    @IBOutlet var sceneView: ARSCNView! {
        didSet {
            let holdRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(reactToLongPress(byReactingTo:)))
            holdRecognizer.minimumPressDuration = CFTimeInterval(0.1)
            sceneView.addGestureRecognizer(holdRecognizer)

            let singleTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(reactToTap(byReactingTo:)))
            sceneView.addGestureRecognizer(singleTapRecognizer)
            
        }
    }
    
    
    
    @objc func reactToLongPress(byReactingTo holdRecognizer: UILongPressGestureRecognizer) {
        // Check tool type and react accordingly here
        switch sessTool.currentMode {
        case .Pen:
            switch holdRecognizer.state {
            case .began:
                userIsDrawing = true
            case .ended:
                userIsDrawing = false
            default: break
            }
            
        case .Manipulator:
            switch holdRecognizer.state {
            case .began:
                userIsMovingStructure = true
            case .ended:
                userIsMovingStructure = false
            default: break
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        var imageView = UIImageView(frame:CGRect(x:self.sceneView.bounds.width/2,y:self.sceneView.bounds.height/2,width:80,height:80))
//
       
        icon.image = recordicon
//        imageView.image = recordicon
//        self.view.addSubview(imageView)

        sceneView.delegate = self
        
        setupScene()
        setupTool()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        

    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    var configuration = ARWorldTrackingConfiguration()
    func setupScene() {
        // Configure and setup the scene view
        configuration.planeDetection = .horizontal
        sceneView.delegate = self
        
        sceneView.antialiasingMode = .multisampling4X
        sceneView.automaticallyUpdatesLighting = true
        sceneView.autoenablesDefaultLighting = true
        sceneView.preferredFramesPerSecond = 60
        sceneView.contentScaleFactor = 1.3
        
        rootNode = sceneView.scene.rootNode
        sceneView.session.run(configuration)
    }
    
    func setupTool() {
        
        sessTool = Tool()
        sessTool.rootNode = self.rootNode!
       
        
        let placeHolderNode = SCNNode()
        positionNode(placeHolderNode, atDist: sessTool.distanceFromCamera - 2)
        
    }
    
    private func positionNode(_ node: SCNNode, atDist dist: Float) {
        node.transform = (sceneView.pointOfView?.transform)!
        var pointerVector = SCNVector3(-1 * node.transform.m31, -1 * node.transform.m32, -1 * node.transform.m33)
        pointerVector.scaleBy(dist)
        node.position += pointerVector
    }

    // MARK: - ARSCNViewDelegate
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
    @objc func reactToTap(byReactingTo singleTapRecognizer: UITapGestureRecognizer) {
        switch sessTool.currentMode {
        case .Manipulator:
            let resultPoints = sceneView.hitTest(singleTapRecognizer.location(in: sceneView), options: nil)
            if resultPoints.count > 0 {
                let resultNode = resultPoints[0].node
                if resultNode.isEqual(sessTool.toolNode) {
                    return
                }
                
                if let parentNode = resultNode.parent {
                    if parentNode.isEqual(rootNode!) {
                        sessTool.updateSelection(withSelectedNode: resultNode)
                    } else {
                        sessTool.updateSelection(withSelectedNode: parentNode)
                    }
                }
            }
        case .Pen:
            break
        }
    }
    
    func updateTool() {
        
        let placeHolderNode = SCNNode()
        positionNode(placeHolderNode, atDist: sessTool.distanceFromCamera)
       
    }
    
    
    var lastPoint: SCNNode?
    func updateDraw(){
        if userIsDrawing {
            if bufferNode == nil {
                // user has started to draw a new line segment
                bufferNode = SCNNode()
                bufferNode!.geometry?.firstMaterial?.emission.contents = UIColor.green
                rootNode?.addChildNode(bufferNode!)
                newPointBuffer = []
            } else {
                // user is currently drawing a line segment, place spheres at pointer position
                let newNode = (SCNNode(geometry: SCNSphere(radius: sessTool.size * 1.5)))
                newNode.geometry?.firstMaterial?.emission.contents = UIColor.green
                newNode.geometry?.firstMaterial?.normal.contents = UIColor.blue
                newNode.geometry?.firstMaterial?.metalness.contents = UIColor.green
                positionNode(newNode, atDist: sessTool.distanceFromCamera)
                
                newPointBuffer!.append(newNode)
                rootNode!.addChildNode(newNode)
                
                if lastPoint == nil {
                    lastPoint = newNode
                } else {
                    let cylinderNode = cylinderFrom(vector: lastPoint!.position, toVector: newNode.position)
                    cylinderNode.position = calculateGlobalAverage([lastPoint!, newNode])
                    cylinderNode.look(at: newNode.position, up: rootNode!.worldUp, localFront: rootNode!.worldUp)
                    rootNode!.addChildNode(cylinderNode)
                    newPointBuffer!.append(cylinderNode)
                    lastPoint = newNode
                }
            }
        } else {
            if bufferNode != nil {
                // user has finished drawing a new line
                let newParent = SCNNode()
                rootNode!.addChildNode(newParent)
                let bestCentroid = calculateGlobalCentroid(newPointBuffer!)
                newParent.position = bestCentroid
                
                rootNode!.addChildNode(newParent)
                
                DispatchQueue.main.async {
                    while self.newPointBuffer!.count > 0 {
                        let newNode = self.newPointBuffer!.removeFirst()
                        let origTrans = newNode.worldTransform
                        newNode.removeFromParentNode()
                        newParent.addChildNode(newNode)
                        newNode.setWorldTransform(origTrans)
                    }
                    self.bufferNode = nil
                    self.lastPoint = nil
                }
            }
        }
    }
    
    func updateMove() {
        if userIsMovingStructure {
            if selectionHolderNode == nil {
                // user has started to move a selection
                if sessTool.selection.isEmpty {
                    return
                }
                
             
                
                selectionHolderNode = SCNNode()
                rootNode?.addChildNode(selectionHolderNode!)
                
                let selectionCentroid = calculateGlobalCentroid(Array(sessTool.selection))
               
                selectionHolderNode!.position = selectionCentroid
                selectionHolderNode!.geometry = SCNSphere(radius: 0.05)
                selectionHolderNode!.geometry?.firstMaterial?.diffuse.contents = UIColor.red
                
                
                DispatchQueue.main.async {
                    for parentNode in self.sessTool.selection {
                        
                        for childNode in parentNode.childNodes {
                            let origTrans = childNode.worldTransform
                            childNode.removeFromParentNode()
                            self.selectionHolderNode!.addChildNode(childNode)
                            childNode.setWorldTransform(origTrans)
                        }
                        parentNode.removeFromParentNode()
                        self.sessTool.updateSelection(withSelectedNode: parentNode) // bad access
                        
                    }
                    self.sessTool.updateSelection(withSelectedNode: self.selectionHolderNode!)
                }
            } else {
                let positionTransformNode = SCNNode()
                let origScale = selectionHolderNode!.scale
                positionNode(positionTransformNode, atDist: sessTool.distanceFromCamera)
                selectionHolderNode!.transform = positionTransformNode.transform
                selectionHolderNode!.scale = origScale
            }
        } else {
            if selectionHolderNode != nil {
                // user has finished moving a selection
                DispatchQueue.main.async {
             
                    
                    if let newNode = self.selectionHolderNode?.clone() {
                        newNode.geometry = nil
                        self.rootNode!.replaceChildNode(self.selectionHolderNode!, with: newNode)
                        self.sessTool.updateSelection(withSelectedNode: self.selectionHolderNode!)
                        self.sessTool.updateSelection(withSelectedNode: newNode)
                    }
                    self.selectionHolderNode!.removeFromParentNode()
                    self.selectionHolderNode = nil
                  
                }
            }
            
        }
    }
    
    private func calculateGlobalAverage(_ nodeList: [SCNNode]) -> SCNVector3 {
        // returns the average position of all nodes in nodeList
        var averagePos = SCNVector3()
        for aNode in nodeList {
            let translVec = aNode.position
            averagePos = averagePos + translVec
        }
        averagePos.scaleBy(1.0/Float(nodeList.count))
        return averagePos
    }
    
    private func calculateGlobalCentroid(_ nodeList: [SCNNode]) -> SCNVector3 {
        // returns the position where each component is the midpoint of the extreme points in the respective axis
        var xExtrema: (xMin: Float, xMax: Float) = (Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)
        var yExtrema: (yMin: Float, yMax: Float) = (Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)
        var zExtrema: (zMin: Float, zMax: Float) = (Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)
        
        for aNode in nodeList {
            let pos = aNode.position
            xExtrema.xMin = min(xExtrema.xMin, pos.x)
            xExtrema.xMax = max(xExtrema.xMax, pos.x)
            
            yExtrema.yMin = min(yExtrema.yMin, pos.y)
            yExtrema.yMax = max(yExtrema.yMax, pos.y)
            
            zExtrema.zMin = min(zExtrema.zMin, pos.z)
            zExtrema.zMax = max(zExtrema.zMax, pos.z)
        }
        
        let xMid = (xExtrema.xMin + xExtrema.xMax) / 2.0
        let yMid = (yExtrema.yMin + yExtrema.yMax) / 2.0
        let zMid = (zExtrema.zMin + zExtrema.zMax) / 2.0
        
        return SCNVector3.init(xMid, yMid, zMid)
    }
    
    private func cylinderFrom(vector vector1: SCNVector3, toVector vector2: SCNVector3) -> SCNNode {
        
        let distBetweenVecs = SCNVector3.SCNVector3Distance(vectorStart: vector1, vectorEnd: vector2)
        
        let retNode = SCNNode()
        retNode.geometry = SCNCylinder(radius: sessTool.size, height: CGFloat(distBetweenVecs))
        
        return retNode
    }
    
    // MARK: - Delegate Methods
    
    func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval) {
        updateDraw()
        updateMove()
        updateTool()
    }
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}
