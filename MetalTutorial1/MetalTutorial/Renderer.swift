import Metal
import MetalKit
import simd

struct Vertex {
    var position: simd_float2
    var color: simd_float3
}

class Renderer: NSObject, MTKViewDelegate {
    var device: MTLDevice
    var commandQueue: MTLCommandQueue
    
    init?(metalKitView: MTKView) {
        //Device and command queue
        self.device = metalKitView.device!
        self.commandQueue = self.device.makeCommandQueue()!
        
        super.init()
    }

    func draw(in view: MTKView) {
        //Create command buffer
        let commandBuffer = self.commandQueue.makeCommandBuffer()!
        
        //Retrieve render pass descriptor and change the background color
        let renderPassDescriptor = view.currentRenderPassDescriptor!
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        
        //Create render command encoder
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        
        //End encoding
        renderEncoder.endEncoding()
        
        //Retrieve drawable and present it to the screen
        let drawable = view.currentDrawable!
        commandBuffer.present(drawable)
            
        //Send our commands to the GPU
        commandBuffer.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    }
}
