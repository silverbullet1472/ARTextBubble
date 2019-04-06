//
//  TextBubble.swift
//  bubbleBlower
//
//  Created by Jiaqi Ding on 2019. 04. 06..
//  Copyright © 2019. Jiaqi Ding. All rights reserved.
//

import Foundation
import ARKit


class TextBubble: SCNNode {
    var textNode : SCNNode!//泡泡包含的文字结点
    init(textContent: String, frontColor: UIColor, backColor: UIColor, middleColor: UIColor, textSize: Float) {
        super.init()
        let text = SCNText(string: textContent, extrusionDepth: 1)
        text.font = UIFont.systemFont(ofSize: 1)
        textNode = SCNNode(geometry: text)
        let m1 = SCNMaterial()//前
        m1.diffuse.contents = frontColor
        let m2 = SCNMaterial()//后
        m2.diffuse.contents = backColor
        let m3 = SCNMaterial()//中
        m3.diffuse.contents = middleColor
        text.materials = [m1,m2,m3]//文字的前中后渲染材质
        text.isWrapped = true//设定文字包裹模式
        text.containerFrame = CGRect(x: 0, y: 0, width: 20, height: 20)//包裹框大小
        text.alignmentMode = kCAAlignmentCenter//居中对齐
        text.truncationMode = kCATruncationNone//裁剪内容方式
        //获取boundingbox，来决定泡泡大小并移动文字旋转中心点至中间
        let (min, max) = text.boundingBox
        let dx = min.x + 0.5 * (max.x - min.x)
        let dy = min.y + 0.5 * (max.y - min.y)
        let dz = min.z + 0.5 * (max.z - min.z)
        textNode.pivot = SCNMatrix4MakeTranslation(dx, dy, dz)
        textNode.eulerAngles = SCNVector3Make(0, 0, 0)
        textNode.position = SCNVector3Make(0, 0, 0)
        //泡泡渲染
        let bubbleGeometry = SCNPlane(width: CGFloat(max.x - min.x) * 1.8, height: CGFloat(max.x - min.x) * 1.8)
        let bubbleMaterial = SCNMaterial()
        bubbleMaterial.diffuse.contents = #imageLiteral(resourceName: "bubbleText")
        bubbleMaterial.isDoubleSided = true
        bubbleMaterial.writesToDepthBuffer = false
        bubbleMaterial.blendMode = .screen
        bubbleGeometry.materials = [bubbleMaterial]
        self.geometry = bubbleGeometry
        self.scale = SCNVector3(textSize, textSize, textSize)
    }
    
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
}
