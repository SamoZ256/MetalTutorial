import Metal
import simd

class ShadowPass {
    var shadowMap: MTLTexture
    
    var renderPipelineState: MTLRenderPipelineState?
    
    init(device: MTLDevice, library: MTLLibrary) {
        // Vertex descriptor
        let vertexDescriptor = MTLVertexDescriptor()
        
        vertexDescriptor.layouts[30].stride = MemoryLayout<Vertex>.stride
        vertexDescriptor.layouts[30].stepRate = 1
        vertexDescriptor.layouts[30].stepFunction = MTLVertexStepFunction.perVertex

        vertexDescriptor.attributes[0].format = MTLVertexFormat.float3
        vertexDescriptor.attributes[0].offset = MemoryLayout.offset(of: \Vertex.position)!
        vertexDescriptor.attributes[0].bufferIndex = 30
        
        // Shadow map
        let shadowMapDescriptor = MTLTextureDescriptor()
        shadowMapDescriptor.pixelFormat = MTLPixelFormat.depth32Float
        shadowMapDescriptor.usage = [.shaderRead, .renderTarget]
        shadowMapDescriptor.width = 2048
        shadowMapDescriptor.height = 2048
        shadowMapDescriptor.storageMode = MTLStorageMode.private
        self.shadowMap = device.makeTexture(descriptor: shadowMapDescriptor)!
        
        // Functions
        let vertexFunction = library.makeFunction(name: "shadowVertexFunction")!
        let fragmentFunction = library.makeFunction(name: "shadowFragmentFunction")!
        
        // Render pipeline state
        let renderPipelineStateDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineStateDescriptor.vertexFunction = vertexFunction
        renderPipelineStateDescriptor.fragmentFunction = fragmentFunction
        renderPipelineStateDescriptor.vertexDescriptor = vertexDescriptor
        renderPipelineStateDescriptor.depthAttachmentPixelFormat = self.shadowMap.pixelFormat
        do {
            self.renderPipelineState = try device.makeRenderPipelineState(descriptor: renderPipelineStateDescriptor)
        } catch {
            print("Failed to create shadow render pipeline state")
        }
    }
    
    func encode(commandBuffer: MTLCommandBuffer, depthStencilState: MTLDepthStencilState, render: (MTLRenderCommandEncoder) -> Void, viewProjMatrix: inout float4x4) {
        // Create render pass descriptor
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.depthAttachment.texture = shadowMap
        renderPassDescriptor.depthAttachment.loadAction = .clear
        renderPassDescriptor.depthAttachment.storeAction = .store
        renderPassDescriptor.depthAttachment.clearDepth = 1.0
        
        // Create render command encoder
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        
        // Bind render pipeline state
        renderEncoder.setRenderPipelineState(self.renderPipelineState!)
        
        // Bind depth stencil state
        renderEncoder.setDepthStencilState(depthStencilState)
        
        // Discard back faces
        renderEncoder.setFrontFacing(.clockwise)
        renderEncoder.setCullMode(.back)
        
        // Upload the view projection matrix
        renderEncoder.setVertexBytes(&viewProjMatrix, length: MemoryLayout.stride(ofValue: viewProjMatrix), index: 0)
        
        // Render
        render(renderEncoder)
        
        // End encoding
        renderEncoder.endEncoding()
    }
}
