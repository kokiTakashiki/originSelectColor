//
//  ViewController.swift
//  originSelectColor
//
//  Created by takasiki on R 1/12/04.
//  Copyright © Reiwa 1 takasiki. All rights reserved.
//

import UIKit
import MetalKit

extension MTKView : RenderDestinationProvider {
}

class ViewController: UIViewController, MTKViewDelegate {

    @IBOutlet weak var DrawView: MTKView!
    
    var renderer: Renderer!
    
    var pressurePoint:float2 = float2(x: 0.0, y: 0.0)
    var timer:Float = 0.0
    
    @IBOutlet weak var testlabel: UILabel! //red value
    @IBOutlet weak var greenLabel: UILabel!
    @IBOutlet weak var blueLabel: UILabel!
    @IBOutlet weak var sizeLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view to use the default device
        DrawView.device = MTLCreateSystemDefaultDevice()
        DrawView.backgroundColor = UIColor.clear
        DrawView.delegate = self
        
        guard DrawView.device != nil else {
            print("Metal is not supported on this device")
            return
        }
        
        let textureLoader = MTKTextureLoader(device: DrawView.device!)
        let path = Bundle.main.path(forResource: "hari031", ofType: "png")!
        let data = NSData(contentsOfFile: path)! as Data
        //let texture = try! textureLoader.newTexture(with: data, options: [MTKTextureLoaderOptionSRGB : (false as NSNumber)])
        let texture = try! textureLoader.newTexture(data: data, options: [MTKTextureLoader.Option.SRGB : (false as NSNumber)])
        
        renderer = Renderer(name: "CreateOrigin", metalDevice: DrawView.device!, texture: texture, renderDestination: DrawView)
        
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }
    
    let startDate = Date()
    var timeCount:Float = 0.0
    var count:Float = 0.0
    
    // Called whenever the view needs to render
    func draw(in view: MTKView) {
        timer = Float(Date().timeIntervalSince(startDate))
        renderer.update(pressurePoint: float2(pressurePoint), time: timer, slcolorVal: colorVal)
    }
    
    var colorVal:float4 = float4(1.0,0.0,0.0,-2.0)
    //red
    @IBAction func testSlider(_ sender: UISlider) {
        testlabel.text = String(sender.value)
        colorVal.x = sender.value
    }
    
    //green
    @IBAction func greenSlider(_ sender: UISlider) {
        greenLabel.text = String(sender.value)
        colorVal.y = sender.value
    }
    
    //blue
    @IBAction func blueSlider(_ sender: UISlider) {
        blueLabel.text = String(sender.value)
        colorVal.z = sender.value
    }
    
    //size
    @IBAction func sizeSlider(_ sender: UISlider) {
        sizeLabel.text = String(sender.value)
        colorVal.w = sender.value
    }
    
    var sawareru:Bool = true
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        if sawareru == true {
            let touch = touches.first
            let touchLocation = (touch?.location(in: DrawView))!
            let touchInit = float2(x: Float((touchLocation.x - DrawView.bounds.width/2) / DrawView.bounds.width),
                                   y: Float((touchLocation.y - DrawView.bounds.height/2) / DrawView.bounds.height) )
            pressurePoint = float2(x: touchInit.x*2.0, y: touchInit.y * -1.2 + 0.2)
            //print(pressurePoint)
        
        }
        
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        //count = 0.0
    }
    
    //touches


}

