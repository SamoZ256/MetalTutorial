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
    
    var library: MTLLibrary
    var vertexFunction: MTLFunction
    var fragmentFunction: MTLFunction
    
    var renderPipelineState: MTLRenderPipelineState?
    
    var vertexBuffer: MTLBuffer
    
    init?(metalKitView: MTKView) {
        //Device and command queue
        self.device = metalKitView.device!
        self.commandQueue = self.device.makeCommandQueue()!
        
        //Library
        self.library = device.makeDefaultLibrary()!
        self.vertexFunction = library.makeFunction(name: "vertexFunction")!
        self.fragmentFunction = library.makeFunction(name: "fragmentFunction")!
        
        //Render pipeline descriptor
        let renderPipelineStateDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineStateDescriptor.vertexFunction = vertexFunction
        renderPipelineStateDescriptor.fragmentFunction = fragmentFunction
        renderPipelineStateDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
        do {
            self.renderPipelineState = try self.device.makeRenderPipelineState(descriptor: renderPipelineStateDescriptor)
        } catch {
            print("Failed to create render pipeline state")
        }
        
        //Create vertex buffer
        let vertices: [Vertex] = [
            Vertex(position: simd_float2(-0.5, -0.5), color: simd_float3(1.0, 0.0, 0.0)), //vertex 0
            Vertex(position: simd_float2( 0.5, -0.5), color: simd_float3(0.0, 1.0, 0.0)), //vertex 1
            Vertex(position: simd_float2( 0.0,  0.5), color: simd_float3(0.0, 0.0, 1.0))  //vertex 2
        ]
        
        self.vertexBuffer = self.device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout.stride(ofValue: vertices[0]), options: MTLResourceOptions.storageModeShared)!
        
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
        
        //Bind render pipeline state
        renderEncoder.setRenderPipelineState(self.renderPipelineState!)
        
        //Bind vertex buffer
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        //Render
        renderEncoder.drawPrimitives(type: MTLPrimitiveType.triangle, vertexStart: 0, vertexCount: 3)
        
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
