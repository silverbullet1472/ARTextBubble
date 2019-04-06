//
//  ViewController.swift
//  soapBubble
//
//  Created by Jiaqi Ding on 2019. 04. 06..
//  Copyright © 2019. Jiaqi Ding. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import CoreAudio
import AVFoundation


class ViewController: UIViewController, ARSCNViewDelegate {
    var imageView:UIImageView!
    @IBOutlet var sceneView: ARSCNView!
    var averageBackgroundNoise:Float?
    var arIsReady = false
    var pressCount = 0
    var isBubbling = false
    var readyToFloat = false
    var currentBubble : TextBubble!
    var bubbles : [TextBubble] = [TextBubble]()
    

    override func viewDidLoad() {
        super.viewDidLoad()
        initMicrophone()

        sceneView.delegate = self
        let scene = SCNScene()
        sceneView.scene = scene
        //长按监听
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        sceneView.addGestureRecognizer(longPressGesture)
        //点击监听
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        sceneView.addGestureRecognizer(tapGesture)
        //校正视图
        let calibrationView = arCalibration(frame:self.view.bounds)
        self.view.addSubview(calibrationView)
        calibrationView.calibrationDone = {  [weak self] done in
            if done {
                self?.initAR()
                self?.sceneView.debugOptions = []
                //self?.sceneView.debugOptions = [ARSCNDebugOptions.showWorldOrigin]//to see coordinate
                self?.arIsReady = true
            }
        }
        
    }
    
    func initAR(){
        imageView = UIImageView(frame: CGRect(x: 0, y: self.view.frame.size.height*0.5, width: self.view.frame.size.width, height: self.view.frame.size.height*0.5))
        imageView.contentMode = .scaleAspectFit
        imageView.image = #imageLiteral(resourceName: "bubble_blower")
        imageView.alpha = 0.9
        self.sceneView.addSubview(imageView)
        
    }
    
    var ARTrackingIsReady:Bool = false {
        didSet{
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "arTrackingReady"), object: nil)
        }
    }
    
    func initMicrophone(){
        //麦克风用来监听声音，从而实现吹气使泡泡移动
        var recorder: AVAudioRecorder
        let audioSession: AVAudioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord)
            try audioSession.setActive(true)
        } catch  {}
        
        let url = URL(fileURLWithPath:"/dev/null")
        
        var settings = Dictionary<String, NSNumber>()
        settings[AVSampleRateKey] = 44100.0
        settings[AVFormatIDKey] = kAudioFormatAppleLossless as NSNumber
        settings[AVNumberOfChannelsKey] = 1
        settings[AVEncoderAudioQualityKey] = 0x7F //max quality hex
        
        do {
            try recorder = AVAudioRecorder(url: url, settings: settings)
            recorder.prepareToRecord()
            recorder.isMeteringEnabled = true
            recorder.record()
            _ = Timer.scheduledTimer(timeInterval: 0.3, target: self, selector: #selector(timerCallBack(timer:)), userInfo: recorder, repeats: true)
        } catch  {}
    }
    
    var averageMicValues = [Float]()
    
    @objc func timerCallBack(timer:Timer){
        //麦克风回调函数，其中situation12尚不清楚实际意义
        let recorder: AVAudioRecorder = timer.userInfo as! AVAudioRecorder
        recorder.updateMeters()
        let avgPower: Float = 160+recorder.averagePower(forChannel: 0)
        if(!arIsReady){
            averageMicValues.append(avgPower)
            averageBackgroundNoise = averageMicValues.average
        }else{
            // 100 dB - silence threshold: 20
            // 130 dB - avg background noise: 4-5
            if avgPower > 130 && averageBackgroundNoise! < Float(120){
                print(String(format:"situation 1:avgPower: %f ,averageBackgroundNoise: %f", arguments:[avgPower,averageBackgroundNoise!]))
            }else if averageBackgroundNoise! > 120 && avgPower > 136{
                print(String(format:"situation 2 :avgPower: %f ,averageBackgroundNoise: %f", arguments:[avgPower,averageBackgroundNoise!]))
                if(readyToFloat){
                    guard let frame = self.sceneView.session.currentFrame else {
                        return
                    }
                    let mat = SCNMatrix4(frame.camera.transform) // 4x4 transform matrix describing camera in world space
                    let dir = SCNVector3(-1 * mat.m31, -1 * mat.m32, -1 * mat.m33) // orientation of camera in world space
                    let floatingAction = SCNAction.move(by: dir + SCNVector3(floatBetween(-1.5, and:1.5 ),floatBetween(0, and: 1.5),0), duration: TimeInterval(floatBetween(8, and: 11)))
                    floatingAction.timingMode = .easeOut
                    if(!isBubbling){
                        currentBubble.runAction(floatingAction)
                        currentBubble.textNode.runAction(floatingAction)
                        readyToFloat = false
                    }
                }
            }
        }
    }
    
    @objc func handleLongPress(_ recgnizer:UILongPressGestureRecognizer){
        if recgnizer.state == .began{
            print("start pressing")
            let textContent : String = "I took the supermarket flowers from the windowsill\n从窗台拾起超市买来的鲜花\nI threw the day old tea from the cup\n怀念着那些旧日里的杯盏老茶\nPacked up the photo album Matthew had made\n打包收好弟弟马修制作的相册\nMemories of a life that's been loved\n和那被敬爱一生的美好回忆"
            let frontColor : UIColor = UIColor(red: CGFloat(90) / 255.0, green: CGFloat(255) / 255.0, blue: CGFloat(255) / 255.0, alpha: CGFloat(1) / 1.0)
            let backColor : UIColor = UIColor(red: CGFloat(255) / 255.0, green: CGFloat(255) / 255.0, blue: CGFloat(255) / 255.0, alpha: CGFloat(0.6) / 1.0)
            let middleColor : UIColor = UIColor(red: CGFloat(255) / 255.0, green: CGFloat(25) / 255.0, blue: CGFloat(85) / 255.0, alpha: CGFloat(1) / 1.0)
            let textSize : Float = Float(0.01)
            currentBubble = TextBubble(textContent: textContent, frontColor: frontColor, backColor: backColor, middleColor: middleColor, textSize: textSize)
            currentBubble.textNode.scale = SCNVector3Make(textSize, textSize, textSize)
            let position = getNewPosition()
            currentBubble.position = position
            currentBubble.textNode.position = position
            let cameraDir = getCameraDirection()
            currentBubble.textNode.eulerAngles = cameraDir//旋转文字使其绕z轴面向手机
            sceneView.scene.rootNode.addChildNode(currentBubble)
            sceneView.scene.rootNode.addChildNode(currentBubble.textNode)
            bubbles.append(currentBubble)//将泡泡加入数组
            isBubbling = true
        }
        if recgnizer.state == .changed{
            if (pressCount<=intBetween(10, and: 30)){
                let scale = 0.01 + CGFloat(pressCount)/2000.0
                let scaleAction = SCNAction.scale(to: scale, duration: 0.7)
                currentBubble.runAction(scaleAction)
                currentBubble.textNode.runAction(scaleAction)
            }
            pressCount+=1
            print(pressCount)
        }
        if recgnizer.state == .ended{
            print("stop pressing")
            pressCount=0
            guard let frame = self.sceneView.session.currentFrame else {
                return
            }
            let mat = SCNMatrix4(frame.camera.transform)
            let dir = SCNVector3(-1 * mat.m31, -1 * mat.m32, -1 * mat.m33)
            let detachAction = SCNAction.move(by: dir.normalized() * 0.5 + SCNVector3(0,0.15,0), duration: 5)
            detachAction.timingMode = .easeOut
            if(isBubbling){
                isBubbling = false
                currentBubble.runAction(detachAction,completionHandler: {
                    let alert = UIAlertController(title: "alert", message: "try bubbling!", preferredStyle: UIAlertControllerStyle.alert)
                    let yes = UIAlertAction(title: "yes", style: UIAlertActionStyle.default,handler:{(alerts:UIAlertAction)->Void in
                        self.readyToFloat = true})
                    alert.addAction(yes)
                    self.present(alert,animated: true)
                })
                currentBubble.textNode.runAction(detachAction)
            }
        }
    }
    
    @objc func handleTap(_ recgnizer:UITapGestureRecognizer){
    }

    func getNewPosition() -> (SCNVector3) { // (direction, position)
        if let frame = self.sceneView.session.currentFrame {
            let mat = SCNMatrix4(frame.camera.transform) // 4x4 transform matrix describing camera in world space
            let dir = SCNVector3(-1 * mat.m31, -1 * mat.m32, -1 * mat.m33) // orientation of camera in world space
            let pos = SCNVector3(mat.m41, mat.m42, mat.m43) // location of camera in world space
            return pos + SCNVector3(0,-0.07,0) + dir.normalized() * 0.5
        }
        return SCNVector3(0, 0, -1)
    }

    func getCameraDirection() -> (SCNVector3) { // (direction, position)
        if let frame = self.sceneView.session.currentFrame {
            let dir = SCNVector3Make(frame.camera.eulerAngles.x, frame.camera.eulerAngles.y, 0)
            return dir
        }
        return SCNVector3(0, 0, 0)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard let frame = self.sceneView.session.currentFrame else {
            return
        }
        let mat = SCNMatrix4(frame.camera.transform) // 4x4 transform matrix describing camera in world space
        let pos = SCNVector3(mat.m41, mat.m42, mat.m43) // location of camera in world space
        for node in bubbles {
            //仅泡泡看向手机，文字不移动
            node.look(at: pos)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
    // MARK: - ARSCNViewDelegate
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        switch camera.trackingState {
        case .notAvailable:
            break
        case .limited:
            break
        case .normal:
            ARTrackingIsReady = true
            break
        }
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

private func floatBetween(_ first: Float,  and second: Float) -> Float {
    // random float between upper and lower bound (inclusive)
    return (Float(arc4random()) / Float(UInt32.max)) * (first - second) + second
}

private func intBetween(_ first: Int,  and second: Int) -> Int {
    //return (Int(arc4random()) / Int(UInt32.max)) * (first - second) + second
    let count = UInt32(second - first)
    return  Int(arc4random_uniform(count)) + first
}

extension SCNVector3 {
    func length() -> Float {
        return sqrtf(x * x + y * y + z * z)
    }
    
    func normalized() -> SCNVector3 {
        if self.length() == 0 {
            return self
        }
        
        return self / self.length()
    }
}
func + (left: SCNVector3, right: SCNVector3) -> SCNVector3 {
    return SCNVector3Make(left.x + right.x, left.y + right.y, left.z + right.z)
}

func * (left: SCNVector3, right: Float) -> SCNVector3 {
    return SCNVector3Make(left.x * right, left.y * right, left.z * right)
}

func / (left: SCNVector3, right: Float) -> SCNVector3 {
    return SCNVector3Make(left.x / right, left.y / right, left.z / right)
}

extension Array where Element: FloatingPoint {
    /// Returns the sum of all elements in the array
    var total: Element {
        return reduce(0, +)
    }
    /// Returns the average of all elements in the array
    var average: Element {
        return isEmpty ? 0 : total / Element(count)
    }
}

func dbToGain(dB:Float) -> Float {
    return pow(2, dB/6)
}

