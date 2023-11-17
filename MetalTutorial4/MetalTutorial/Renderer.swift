import Metal
import MetalKit
import simd

struct Vertex {
    var position: simd_float3
    var texCoord: simd_float2
}

class Renderer: NSObject, MTKViewDelegate {
    //Metal objects
    var device: MTLDevice
    var commandQueue: MTLCommandQueue
    
    var vertexDescriptor: MTLVertexDescriptor
    
    var library: MTLLibrary
    var vertexFunction: MTLFunction
    var fragmentFunction: MTLFunction
    
    var renderPipelineState: MTLRenderPipelineState?
    
    var vertexBuffer: MTLBuffer
    var indexBuffer: MTLBuffer
    
    var colorTexture: MTLTexture?
    
    //Window size
    var windowSize: CGSize = CGSizeZero
    var aspectRatio: Float = 1.0
    
    init?(metalKitView: MTKView) {
        //Device and command queue
        self.device = metalKitView.device!
        self.commandQueue = self.device.makeCommandQueue()!
        
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
        
        //Library
        self.library = device.makeDefaultLibrary()!
        self.vertexFunction = library.makeFunction(name: "vertexFunction")!
        self.fragmentFunction = library.makeFunction(name: "fragmentFunction")!
        
        //Render pipeline descriptor
        let renderPipelineStateDescriptor = MTLRenderPipelineDescriptor()
        renderPipelineStateDescriptor.vertexFunction = vertexFunction
        renderPipelineStateDescriptor.fragmentFunction = fragmentFunction
        renderPipelineStateDescriptor.vertexDescriptor = vertexDescriptor
        renderPipelineStateDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
        do {
            self.renderPipelineState = try self.device.makeRenderPipelineState(descriptor: renderPipelineStateDescriptor)
        } catch {
            print("Failed to create render pipeline state")
        }
        
        //Create vertex buffer
        let vertices: [Vertex] = [
            Vertex(position: simd_float3(-0.5, -0.5, 0.0), texCoord: simd_float2(0.0, 1.0)), //vertex 0
            Vertex(position: simd_float3( 0.5, -0.5, 0.0), texCoord: simd_float2(1.0, 1.0)), //vertex 1
            Vertex(position: simd_float3( 0.5,  0.5, 0.0), texCoord: simd_float2(1.0, 0.0)), //vertex 2
            Vertex(position: simd_float3(-0.5,  0.5, 0.0), texCoord: simd_float2(0.0, 0.0))  //vertex 3
        ]
        
        self.vertexBuffer = self.device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout.stride(ofValue: vertices[0]), options: MTLResourceOptions.storageModeShared)!
        
        //Create index buffer
        let indices: [ushort] = [
            0, 1, 2,
            0, 2, 3
        ]
        
        self.indexBuffer = self.device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout.stride(ofValue: indices[0]), options: MTLResourceOptions.storageModeShared)!
        
        let loader = MTKTextureLoader(device: self.device)
        
        do {
            let url = Bundle.main.url(forResource: "metal_logo", withExtension: "png")
            self.colorTexture = try loader.newTexture(URL: url!, options: nil)
        } catch {
            print("Failed to load image 'metal_logo.png'")
        }
        
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
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 30)
        
        //Bind color texture
        renderEncoder.setFragmentTexture(colorTexture, index: 0)
        
        //Create the projection matrix
        var projectionMatrix = createPerspectiveMatrix(fov: toRadians(from: 45.0), aspectRatio: aspectRatio, nearPlane: 0.1, farPlane: 100.0)
        renderEncoder.setVertexBytes(&projectionMatrix, length: MemoryLayout.stride(ofValue: projectionMatrix), index: 0)
        
        //Create the view matrix
        let viewMatrix = createViewMatrix(eyePosition: simd_float3(0.0, 5.0, -5.0), targetPosition: simd_float3(0.0, 0.0, 0.0), upVec: simd_float3(0.0, 1.0, 0.0))
        
        //Create the model matrix
        var modelMatrix = matrix_identity_float4x4
        translateMatrix(matrix: &modelMatrix, position: simd_float3(0.0, 0.0, 0.0))
        rotateMatrix(matrix: &modelMatrix, rotation: simd_float3(0.0, toRadians(from: 60.0), 0.0))
        scaleMatrix(matrix: &modelMatrix, scale: simd_float3(1.0, 1.0, 1.0))
        
        var modelViewMatrix = viewMatrix * modelMatrix
        renderEncoder.setVertexBytes(&modelViewMatrix, length: MemoryLayout.stride(ofValue: modelViewMatrix), index: 1)
        
        //Render
        renderEncoder.drawIndexedPrimitives(type: MTLPrimitiveType.triangle, indexCount: 6, indexType: MTLIndexType.uint16, indexBuffer: indexBuffer, indexBufferOffset: 0)
        
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
