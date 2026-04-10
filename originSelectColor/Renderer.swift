//
//  Renderer.swift
//  metalHanabi01
//
//  Created by takasiki on 5/26/1 R.
//  Copyright © 1 Reiwa takasiki. All rights reserved.
//

import Foundation
import Metal
import MetalKit
import simd

protocol RenderDestinationProvider {
    var currentRenderPassDescriptor: MTLRenderPassDescriptor? { get }
    var currentDrawable: CAMetalDrawable? { get }
    var colorPixelFormat: MTLPixelFormat { get set }
    var depthStencilPixelFormat: MTLPixelFormat { get set }
    var sampleCount: Int { get set }
}

// The max number of command buffers in flight
let kMaxBuffersInFlight: Int = 3

// 三角系の頂点座標
//    let vertexArray: [Float] = [
//        0.0, 0.1,
//        -0.1, -0.1,
//        0.1, -0.1
//    ]
// Vertex data for an image plane
let imageVertexArray: [Float] = [
    -1.0, -1.0,  0.0, 1.0,
    1.0, -1.0,  1.0, 1.0,
    -1.0,  1.0,  0.0, 0.0,
    1.0,  1.0,  1.0, 0.0,
]

class Renderer {
    
    let device: MTLDevice!
    let inFlightSemaphore = DispatchSemaphore(value: kMaxBuffersInFlight)
    var renderDestination: RenderDestinationProvider
    
    var commandQueue: MTLCommandQueue!
    //var mesh: MTKMesh!
    var imagePlaneVertexBuffer: MTLBuffer!
    var imagePipelineState: MTLRenderPipelineState!
    
    var timer: Float = 0
    var texture: MTLTexture
    
    init(name: String, metalDevice device: MTLDevice, texture: MTLTexture, renderDestination: RenderDestinationProvider) {
        self.device = device
        self.texture = texture
        self.renderDestination = renderDestination
        loadMetal()
    }
    
    func update(pressurePoint: float2, time: Float, slcolorVal: float4){
        //let _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        // Create a new command buffer for each renderpass to the current drawable
        if let commandBuffer = commandQueue.makeCommandBuffer() {
            commandBuffer.label = "MyCommand"
            
            if let renderPassDescriptor = renderDestination.currentRenderPassDescriptor, let currentDrawable = renderDestination.currentDrawable, let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                
                renderEncoder.label = "MyRenderEncoder"
                
                drawImage(renderEncoder: renderEncoder, pressurePoint: pressurePoint, time: time, slcolorVal: slcolorVal)
                
                // We're done encoding commands
                renderEncoder.endEncoding()
                
                // Schedule a present once the framebuffer is complete using the current drawable
                commandBuffer.present(currentDrawable)
            }
            
            // Finalize rendering here & push the command buffer to the GPU
            commandBuffer.commit()
        }
    }
    
    func loadMetal(){
        // Set the default formats needed to render
        renderDestination.depthStencilPixelFormat = .invalid//.depth32Float_stencil8
        renderDestination.colorPixelFormat = .bgra8Unorm
        renderDestination.sampleCount = 1
        
        let imageVertexArrayDataCount = imageVertexArray.count * MemoryLayout<Float>.size
        imagePlaneVertexBuffer = device.makeBuffer(bytes: imageVertexArray, length: imageVertexArrayDataCount, options: [])
        imagePlaneVertexBuffer.label = "ImagePlaneVertexBuffer"
        
        let library = device.makeDefaultLibrary()
        let vertexFunction = library?.makeFunction(name: "vertex_main")
        let fragmentFunction = library?.makeFunction(name: "fragment_main")
        
        // Create a vertex descriptor for our image plane vertex buffer
        let imagePlaneVertexDescriptor = MTLVertexDescriptor()
        
        // Positions.
        imagePlaneVertexDescriptor.attributes[0].format = .float2
        imagePlaneVertexDescriptor.attributes[0].offset = 0
        imagePlaneVertexDescriptor.attributes[0].bufferIndex = 0
        
        // Texture coordinates.
        imagePlaneVertexDescriptor.attributes[1].format = .float2
        imagePlaneVertexDescriptor.attributes[1].offset = 8
        imagePlaneVertexDescriptor.attributes[1].bufferIndex = 0
        
        // Buffer Layout
        imagePlaneVertexDescriptor.layouts[0].stride = 16
        imagePlaneVertexDescriptor.layouts[0].stepRate = 1
        imagePlaneVertexDescriptor.layouts[0].stepFunction = .perVertex
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "MyImagePipeline"
        pipelineDescriptor.sampleCount = renderDestination.sampleCount
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = imagePlaneVertexDescriptor
        pipelineDescriptor.colorAttachments[0].pixelFormat = renderDestination.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = renderDestination.depthStencilPixelFormat
        pipelineDescriptor.stencilAttachmentPixelFormat = renderDestination.depthStencilPixelFormat
        do {
            imagePipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch let error {
            fatalError(error.localizedDescription)
            //print("error with device.newRenderPipelineStateWithDescriptor")
        }
        
        // Create the command queue
        commandQueue = device.makeCommandQueue()
    }
    
    
    func drawImage(renderEncoder: MTLRenderCommandEncoder, pressurePoint: float2, time:Float, slcolorVal: float4) {
//        guard let textureY = capturedImageTextureY, let textureCbCr = capturedImageTextureCbCr else {
//            return
//        }
        
        // Push a debug group allowing us to identify render commands in the GPU Frame Capture tool
        renderEncoder.pushDebugGroup("DrawImage")
        
        // pressurePoint
        var pressureBuffer1: MTLBuffer! = nil
        pressureBuffer1 = device.makeBuffer(length: MemoryLayout<float2>.size, options: [])
        pressureBuffer1.label = "pressureZone1"
        let vPressureBuffer1Data = pressureBuffer1.contents().bindMemory(to: float2.self, capacity: 1 / MemoryLayout<float2>.stride)
        vPressureBuffer1Data[0] = pressurePoint
        
        // time
        var timeBuffer: MTLBuffer! = nil
        timeBuffer = device.makeBuffer(length: MemoryLayout<Float>.size, options: [])
        timeBuffer.label = "time"
        let vTimeData = timeBuffer.contents().bindMemory(to: Float.self, capacity: 1 / MemoryLayout<Float>.stride)
        vTimeData[0] = time
        
        // slider color value
        var slcolorBuffer: MTLBuffer! = nil
        slcolorBuffer = device.makeBuffer(length: MemoryLayout<float4>.size, options: [])
        slcolorBuffer.label = "slcolorBuffer"
        let vSlcolorData = slcolorBuffer.contents().bindMemory(to: float4.self, capacity: 1 / MemoryLayout<float4>.stride)
        vSlcolorData[0] = slcolorVal
        
        //vertex
        //renderEncoder.setVertexBuffer(timeBuffer, offset: 0, index: 10)
        //renderEncoder.setVertexBytes(&currentTime, length: MemoryLayout<Float>.stride, index: 1)
        
        //fragment
        renderEncoder.setFragmentBuffer(timeBuffer, offset: 0, index: 1)
        renderEncoder.setFragmentBuffer(pressureBuffer1, offset: 0, index: 2)
        renderEncoder.setFragmentBuffer(slcolorBuffer, offset: 0, index: 3)
        
        // Set render command encoder state
        //renderEncoder.setCullMode(.none)
        renderEncoder.setRenderPipelineState(imagePipelineState)
        //renderEncoder.setDepthStencilState(capturedImageDepthState)
        
        // Set mesh's vertex buffers
        renderEncoder.setVertexBuffer(imagePlaneVertexBuffer, offset: 0, index: 0)
        
        // Set any textures read/sampled from our render pipeline
        //renderEncoder.setFragmentTexture(kokeTexture, index: 0)
        
        // Draw each submesh of our mesh
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        //renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: 4)
        
        renderEncoder.popDebugGroup()
    }
}

