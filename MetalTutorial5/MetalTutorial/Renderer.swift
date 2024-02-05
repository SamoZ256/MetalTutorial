import Metal
import MetalKit
import simd

struct Vertex {
    var position: simd_float3
    var texCoord: simd_float2
    var normal: simd_float3
}

let vertices: [Vertex] = [
    //Front
    Vertex(position: simd_float3(-0.5, -0.5, -0.5), texCoord: simd_float2(0.0, 1.0), normal: simd_float3(0.0, 0.0, -1.0)),
    Vertex(position: simd_float3( 0.5, -0.5, -0.5), texCoord: simd_float2(1.0, 1.0), normal: simd_float3(0.0, 0.0, -1.0)),
    Vertex(position: simd_float3( 0.5,  0.5, -0.5), texCoord: simd_float2(1.0, 0.0), normal: simd_float3(0.0, 0.0, -1.0)),
    Vertex(position: simd_float3(-0.5,  0.5, -0.5), texCoord: simd_float2(0.0, 0.0), normal: simd_float3(0.0, 0.0, -1.0)),
    
    //Back
    Vertex(position: simd_float3(-0.5, -0.5,  0.5), texCoord: simd_float2(0.0, 1.0), normal: simd_float3(0.0, 0.0, 1.0)),
    Vertex(position: simd_float3( 0.5, -0.5,  0.5), texCoord: simd_float2(1.0, 1.0), normal: simd_float3(0.0, 0.0, 1.0)),
    Vertex(position: simd_float3( 0.5,  0.5,  0.5), texCoord: simd_float2(1.0, 0.0), normal: simd_float3(0.0, 0.0, 1.0)),
    Vertex(position: simd_float3(-0.5,  0.5,  0.5), texCoord: simd_float2(0.0, 0.0), normal: simd_float3(0.0, 0.0, 1.0)),
    
    //Left
    Vertex(position: simd_float3(-0.5,  0.5, -0.5), texCoord: simd_float2(0.0, 1.0), normal: simd_float3(-1.0, 0.0, 0.0)),
    Vertex(position: simd_float3(-0.5, -0.5, -0.5), texCoord: simd_float2(1.0, 1.0), normal: simd_float3(-1.0, 0.0, 0.0)),
    Vertex(position: simd_float3(-0.5, -0.5,  0.5), texCoord: simd_float2(1.0, 0.0), normal: simd_float3(-1.0, 0.0, 0.0)),
    Vertex(position: simd_float3(-0.5,  0.5,  0.5), texCoord: simd_float2(0.0, 0.0), normal: simd_float3(-1.0, 0.0, 0.0)),
    
    //Right
    Vertex(position: simd_float3( 0.5,  0.5, -0.5), texCoord: simd_float2(0.0, 1.0), normal: simd_float3(1.0, 0.0, 0.0)),
    Vertex(position: simd_float3( 0.5, -0.5, -0.5), texCoord: simd_float2(1.0, 1.0), normal: simd_float3(1.0, 0.0, 0.0)),
    Vertex(position: simd_float3( 0.5, -0.5,  0.5), texCoord: simd_float2(1.0, 0.0), normal: simd_float3(1.0, 0.0, 0.0)),
    Vertex(position: simd_float3( 0.5,  0.5,  0.5), texCoord: simd_float2(0.0, 0.0), normal: simd_float3(1.0, 0.0, 0.0)),
    
    //Bottom
    Vertex(position: simd_float3(-0.5, -0.5, -0.5), texCoord: simd_float2(0.0, 1.0), normal: simd_float3(0.0, -1.0, 0.0)),
    Vertex(position: simd_float3( 0.5, -0.5, -0.5), texCoord: simd_float2(1.0, 1.0), normal: simd_float3(0.0, -1.0, 0.0)),
    Vertex(position: simd_float3( 0.5, -0.5,  0.5), texCoord: simd_float2(1.0, 0.0), normal: simd_float3(0.0, -1.0, 0.0)),
    Vertex(position: simd_float3(-0.5, -0.5,  0.5), texCoord: simd_float2(0.0, 0.0), normal: simd_float3(0.0, -1.0, 0.0)),
    
    //Top
    Vertex(position: simd_float3(-0.5,  0.5, -0.5), texCoord: simd_float2(0.0, 1.0), normal: simd_float3(0.0, 1.0, 0.0)),
    Vertex(position: simd_float3( 0.5,  0.5, -0.5), texCoord: simd_float2(1.0, 1.0), normal: simd_float3(0.0, 1.0, 0.0)),
    Vertex(position: simd_float3( 0.5,  0.5,  0.5), texCoord: simd_float2(1.0, 0.0), normal: simd_float3(0.0, 1.0, 0.0)),
    Vertex(position: simd_float3(-0.5,  0.5,  0.5), texCoord: simd_float2(0.0, 0.0), normal: simd_float3(0.0, 1.0, 0.0))
]

let indices: [ushort] = [
    //Front
    0, 3, 2,
    2, 1, 0,
    
    //Back
    4, 5, 6,
    6, 7 ,4,
    
    //Left
    11, 8, 9,
    9, 10, 11,
    
    //Right
    12, 13, 14,
    14, 15, 12,
    
    //Bottom
    16, 17, 18,
    18, 19, 16,
    
    //Top
    20, 21, 22,
    22, 23, 20
]

class Renderer: NSObject, MTKViewDelegate {
    //Metal objects
    var device: MTLDevice
    var commandQueue: MTLCommandQueue
    
    var vertexDescriptor: MTLVertexDescriptor
    
    var library: MTLLibrary
    var vertexFunction: MTLFunction
    var fragmentFunction: MTLFunction
    
    var renderPipelineState: MTLRenderPipelineState?
    var depthStencilState: MTLDepthStencilState?
    
    var vertexBuffer: MTLBuffer
    var indexBuffer: MTLBuffer
    
    var colorTexture: MTLTexture?
    
    //Window size
    var windowSize: CGSize = CGSizeZero
    var aspectRatio: Float = 1.0
    
    //Camera
    var viewPosition = simd_float3(4.5, 5.0, 0.0)
    
    init?(metalKitView: MTKView) {
        //Device and command queue
        self.device = metalKitView.device!
        self.commandQueue = self.device.makeCommandQueue()!
        
        metalKitView.depthStencilPixelFormat = MTLPixelFormat.depth32Float
        
        //Vertex descriptor
        vertexDescriptor = MTLVertexDescriptor()
        
        vertexDescriptor.layouts[30].stride = MemoryLayout<Vertex>.stride
        vertexDescriptor.layouts[30].stepRate = 1
        vertexDescriptor.layouts[30].stepFunction = MTLVertexStepFunction.perVertex

        vertexDescriptor.attributes[0].format = MTLVertexFormat.float3
        vertexDescriptor.attributes[0].offset = MemoryLayout.offset(of: \Vertex.position)!
        vertexDescriptor.attributes[0].bufferIndex = 30

        vertexDescriptor.attributes[1].format = MTLVertexFormat.float2
        vertexDescriptor.attributes[1].offset = MemoryLayout.offset(of: \Vertex.texCoord)!
        vertexDescriptor.attributes[1].bufferIndex = 30
        
        vertexDescriptor.attributes[2].format = MTLVertexFormat.float3
        vertexDescriptor.attributes[2].offset = MemoryLayout.offset(of: \Vertex.normal)!
        vertexDescriptor.attributes[2].bufferIndex = 30
        
        //Library
        self.library = device.makeDefaultLibrary()!
        self.vertexFunction = library.makeFunction(name: "vertexFunction")!
        self.fragmentFunction = library.makeFunction(name: "fragmentFunction")!
        
        //Render pipeline state
        let renderPipelineStateDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineStateDescriptor.vertexFunction = vertexFunction
        renderPipelineStateDescriptor.fragmentFunction = fragmentFunction
        renderPipelineStateDescriptor.vertexDescriptor = vertexDescriptor
        renderPipelineStateDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
        renderPipelineStateDescriptor.depthAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        do {
            self.renderPipelineState = try self.device.makeRenderPipelineState(descriptor: renderPipelineStateDescriptor)
        } catch {
            print("Failed to create render pipeline state")
        }
        
        //Depth stencil state
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = MTLCompareFunction.less
        depthStencilDescriptor.isDepthWriteEnabled = true
        depthStencilState = self.device.makeDepthStencilState(descriptor: depthStencilDescriptor)
        
        //Create vertex buffer
        self.vertexBuffer = self.device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout.stride(ofValue: vertices[0]), options: MTLResourceOptions.storageModeShared)!
        
        //Create index buffer
        self.indexBuffer = self.device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout.stride(ofValue: indices[0]), options: MTLResourceOptions.storageModeShared)!
        
        let loader = MTKTextureLoader(device: self.device)
        
        do {
            let url = Bundle.main.url(forResource: "planks", withExtension: "png")
            self.colorTexture = try loader.newTexture(URL: url!, options: nil)
        } catch {
            print("Failed to load image 'planks.png'")
        }
        
        super.init()
    }

    func draw(in view: MTKView) {
        viewPosition.x = Float(5.0 * sin(Date().timeIntervalSince1970))
        viewPosition.z = Float(5.0 * cos(Date().timeIntervalSince1970))
        
        //Create command buffer
        let commandBuffer = self.commandQueue.makeCommandBuffer()!
        
        //Retrieve render pass descriptor and change the background color
        let renderPassDescriptor = view.currentRenderPassDescriptor!
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.416, green: 0.636, blue: 0.722, alpha: 1.0)
        renderPassDescriptor.depthAttachment.clearDepth = 1.0
        
        //Create render command encoder
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        
        //Bind render pipeline state
        renderEncoder.setRenderPipelineState(self.renderPipelineState!)
        
        //Bind depth stencil state
        renderEncoder.setDepthStencilState(self.depthStencilState)
        
        //Bind vertex buffer
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 30)
        
        //Bind color texture
        renderEncoder.setFragmentTexture(colorTexture, index: 0)
        
        //Create the projection matrix
        var projectionMatrix = createPerspectiveMatrix(fov: toRadians(from: 45.0), aspectRatio: aspectRatio, nearPlane: 0.1, farPlane: 100.0)
        renderEncoder.setVertexBytes(&projectionMatrix, length: MemoryLayout.stride(ofValue: projectionMatrix), index: 0)
        
        //Create the view matrix
        var viewMatrix = createViewMatrix(eyePosition: viewPosition, targetPosition: simd_float3(0.0, 0.0, 0.0), upVec: simd_float3(0.0, 1.0, 0.0))
        renderEncoder.setVertexBytes(&viewMatrix, length: MemoryLayout.stride(ofValue: viewMatrix), index: 1)
        
        //Upload view position
        renderEncoder.setFragmentBytes(&viewPosition, length: MemoryLayout.stride(ofValue: viewPosition), index: 0)
        
        //Create the model matrix
        var modelMatrix = matrix_identity_float4x4
        translateMatrix(matrix: &modelMatrix, position: simd_float3(0.0, 0.0, 0.0))
        rotateMatrix(matrix: &modelMatrix, rotation: simd_float3(0.0, toRadians(from: 60.0), 0.0))
        scaleMatrix(matrix: &modelMatrix, scale: simd_float3(1.0, 1.0, 1.0))
        renderEncoder.setVertexBytes(&modelMatrix, length: MemoryLayout.stride(ofValue: modelMatrix), index: 2)
        
        //Render
        renderEncoder.drawIndexedPrimitives(type: MTLPrimitiveType.triangle, indexCount: indices.count, indexType: MTLIndexType.uint16, indexBuffer: indexBuffer, indexBufferOffset: 0)
        
        //End encoding
        renderEncoder.endEncoding()
        
        //Retrieve drawable and present it to the screen
        let drawable = view.currentDrawable!
        commandBuffer.present(drawable)
            
        //Send our commands to the GPU
        commandBuffer.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        self.windowSize = size
        self.aspectRatio = Float(self.windowSize.width) / Float(self.windowSize.height)
    }
}
