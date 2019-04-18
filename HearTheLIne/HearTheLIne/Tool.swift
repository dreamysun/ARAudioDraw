//
//  Tool.swift
//  HearTheLIne
//
//  Created by Dreamy Sun on 4/17/19.
//  Copyright © 2019 ChenyuSun. All rights reserved.
//


import Foundation
import CoreGraphics
import SceneKit

class Tool {
    
    // MARK: - Class Properties
    var size: CGFloat
    var distanceFromCamera: Float
    var currentMode: toolMode
    var rootNode: SCNNode?
    var toolNode: UIImage!
    var selection: Set<SCNNode>
    
    // MARK: - Initializers
    init() {
        size = CGFloat(0.007)
        distanceFromCamera = 0.5
        currentMode = toolMode.Pen
        selection = []
        // toolNode = SCNNode()
        toolNode = UIImage(named:"recordicon")
    }
    
    enum toolMode {
        
        case Pen
        /*
         The pen tool draws lines
         Pressing and holding should begin drawing a line
         Pinching should change the size of the pen
         */
        
        case Manipulator
        /*
         The manipulator lets you reposition and resize nodes
         Tapping objects should add/remove them to current selection and change their color
         Pressing and holding should let you reposition the current selection
         Pinching should change the size of all nodes in the current selection
         */
    }
    
    // MARK: - Public Class Methods
    
    func updateSelection(withSelectedNode parentNode: SCNNode) {
        if selection.contains(parentNode) {
            selection.remove(parentNode) // bad access
            for childNode in parentNode.childNodes {
                childNode.geometry?.firstMaterial?.diffuse.contents = UIColor.white
            }
        } else {
            selection.insert(parentNode)
            for childNode in parentNode.childNodes {
                childNode.geometry?.firstMaterial?.diffuse.contents = UIColor.darkGray
            }
        }
    }
    
    func changeMode(_ newMode: toolMode) {
        self.currentMode = newMode
    }
    
    
    func pinch(_ recognizer: UIPinchGestureRecognizer) {
        switch currentMode {
        case .Pen:
            switch recognizer.state {
            case .began, .changed:
                size *= recognizer.scale
                recognizer.scale = 1
            default: break
            }
        case .Manipulator:
            switch recognizer.state {
            case .began, .changed:
                for parentNode in selection {
                    parentNode.scale.scaleBy(Float(recognizer.scale))
                    recognizer.scale = 1
                }
            default: break
            }
        }
    }
    
    
 
    
}
