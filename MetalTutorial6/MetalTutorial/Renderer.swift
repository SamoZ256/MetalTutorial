import Metal
import MetalKit
import GameController
import simd

struct Vertex {
    var position: simd_float3
    var texCoord: simd_float2
    var normal: simd_float3
}

let vertices: [Vertex] = [
    // Front
    Vertex(position: simd_float3(-0.5, -0.5, -0.5), texCoord: simd_float2(0.0, 1.0), normal: simd_float3(0.0, 0.0, -1.0)),
    Vertex(position: simd_float3( 0.5, -0.5, -0.5), texCoord: simd_float2(1.0, 1.0), normal: simd_float3(0.0, 0.0, -1.0)),
    Vertex(position: simd_float3( 0.5,  0.5, -0.5), texCoord: simd_float2(1.0, 0.0), normal: simd_float3(0.0, 0.0, -1.0)),
    Vertex(position: simd_float3(-0.5,  0.5, -0.5), texCoord: simd_float2(0.0, 0.0), normal: simd_float3(0.0, 0.0, -1.0)),
    
    // Back
    Vertex(position: simd_float3(-0.5, -0.5,  0.5), texCoord: simd_float2(0.0, 1.0), normal: simd_float3(0.0, 0.0, 1.0)),
    Vertex(position: simd_float3( 0.5, -0.5,  0.5), texCoord: simd_float2(1.0, 1.0), normal: simd_float3(0.0, 0.0, 1.0)),
    Vertex(position: simd_float3( 0.5,  0.5,  0.5), texCoord: simd_float2(1.0, 0.0), normal: simd_float3(0.0, 0.0, 1.0)),
    Vertex(position: simd_float3(-0.5,  0.5,  0.5), texCoord: simd_float2(0.0, 0.0), normal: simd_float3(0.0, 0.0, 1.0)),
    
    // Left
    Vertex(position: simd_float3(-0.5,  0.5, -0.5), texCoord: simd_float2(0.0, 1.0), normal: simd_float3(-1.0, 0.0, 0.0)),
    Vertex(position: simd_float3(-0.5, -0.5, -0.5), texCoord: simd_float2(1.0, 1.0), normal: simd_float3(-1.0, 0.0, 0.0)),
    Vertex(position: simd_float3(-0.5, -0.5,  0.5), texCoord: simd_float2(1.0, 0.0), normal: simd_float3(-1.0, 0.0, 0.0)),
    Vertex(position: simd_float3(-0.5,  0.5,  0.5), texCoord: simd_float2(0.0, 0.0), normal: simd_float3(-1.0, 0.0, 0.0)),
    
    // Right
    Vertex(position: simd_float3( 0.5,  0.5, -0.5), texCoord: simd_float2(0.0, 1.0), normal: simd_float3(1.0, 0.0, 0.0)),
    Vertex(position: simd_float3( 0.5, -0.5, -0.5), texCoord: simd_float2(1.0, 1.0), normal: simd_float3(1.0, 0.0, 0.0)),
    Vertex(position: simd_float3( 0.5, -0.5,  0.5), texCoord: simd_float2(1.0, 0.0), normal: simd_float3(1.0, 0.0, 0.0)),
    Vertex(position: simd_float3( 0.5,  0.5,  0.5), texCoord: simd_float2(0.0, 0.0), normal: simd_float3(1.0, 0.0, 0.0)),
    
    // Bottom
    Vertex(position: simd_float3(-0.5, -0.5, -0.5), texCoord: simd_float2(0.0, 1.0), normal: simd_float3(0.0, -1.0, 0.0)),
    Vertex(position: simd_float3( 0.5, -0.5, -0.5), texCoord: simd_float2(1.0, 1.0), normal: simd_float3(0.0, -1.0, 0.0)),
    Vertex(position: simd_float3( 0.5, -0.5,  0.5), texCoord: simd_float2(1.0, 0.0), normal: simd_float3(0.0, -1.0, 0.0)),
    Vertex(position: simd_float3(-0.5, -0.5,  0.5), texCoord: simd_float2(0.0, 0.0), normal: simd_float3(0.0, -1.0, 0.0)),
    
    // Top
    Vertex(position: simd_float3(-0.5,  0.5, -0.5), texCoord: simd_float2(0.0, 1.0), normal: simd_float3(0.0, 1.0, 0.0)),
    Vertex(position: simd_float3( 0.5,  0.5, -0.5), texCoord: simd_float2(1.0, 1.0), normal: simd_float3(0.0, 1.0, 0.0)),
    Vertex(position: simd_float3( 0.5,  0.5,  0.5), texCoord: simd_float2(1.0, 0.0), normal: simd_float3(0.0, 1.0, 0.0)),
    Vertex(position: simd_float3(-0.5,  0.5,  0.5), texCoord: simd_float2(0.0, 0.0), normal: simd_float3(0.0, 1.0, 0.0))
]

let indices: [ushort] = [
    // Front
    0, 3, 2,
    2, 1, 0,
    
    // Back
    4, 5, 6,
    6, 7 ,4,
    
    // Left
    11, 8, 9,
    9, 10, 11,
    
    // Right
    12, 14, 13,
    12, 15, 14,
    
    // Bottom
    16, 17, 18,
    18, 19, 16,
    
    // Top
    20, 22, 21,
    20, 23, 22
]

class Renderer: NSObject, MTKViewDelegate {
    // Metal objects
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
    
    // Textures
    var diffuseTexture: MTLTexture?
    var specularTexture: MTLTexture?
    
    // Window size
    var windowSize: CGSize = CGSizeZero
    var aspectRatio: Float = 1.0
    
    // Camera
    var camera = Camera()
    
    // Input devices
    var keyboards = Array<GCKeyboard>()
    
    var rightJoystick = simd_float2(0.0, 0.0)
    
    // Time
    var lastTime: Double
    
    init?(metalKitView: MTKView) {
        // Device and command queue
        self.device = metalKitView.device!
        self.commandQueue = self.device.makeCommandQueue()!
        
        metalKitView.depthStencilPixelFormat = MTLPixelFormat.depth32Float
        
        // Vertex descriptor
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
        
        // Library
        self.library = device.makeDefaultLibrary()!
        self.vertexFunction = library.makeFunction(name: "vertexFunction")!
        self.fragmentFunction = library.makeFunction(name: "fragmentFunction")!
        
        // Render pipeline state
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
        
        // Depth stencil state
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = MTLCompareFunction.less
        depthStencilDescriptor.isDepthWriteEnabled = true
        depthStencilState = self.device.makeDepthStencilState(descriptor: depthStencilDescriptor)
        
        // Create vertex buffer
        self.vertexBuffer = self.device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout.stride(ofValue: vertices[0]), options: MTLResourceOptions.storageModeShared)!
        
        // Create index buffer
        self.indexBuffer = self.device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout.stride(ofValue: indices[0]), options: MTLResourceOptions.storageModeShared)!
        
        // Loading textures
        let loader = MTKTextureLoader(device: self.device)
        
        do {
            let url = Bundle.main.url(forResource: "planks", withExtension: "png")
            self.diffuseTexture = try loader.newTexture(URL: url!, options: nil)
        } catch {
            print("Failed to load image 'planks.png'")
        }
        
        do {
            let url = Bundle.main.url(forResource: "planks_specular", withExtension: "png")
            self.specularTexture = try loader.newTexture(URL: url!, options: nil)
        } catch {
            print("Failed to load image 'planks_specular.png'")
        }
        
        // Time
        lastTime = Date().timeIntervalSince1970
        
        super.init()
    }

    func draw(in view: MTKView) {
        // Delta time
        let crntTime = Date().timeIntervalSince1970
        let dt = Float(crntTime - self.lastTime)
        self.lastTime = crntTime
        
        var leftJoystick = simd_float2(0.0, 0.0)
        for keyboard in self.keyboards {
            if keyboard.keyboardInput!.button(forKeyCode: .keyW)!.value > 0.5 {
                leftJoystick.y += 1.0
            }
            if keyboard.keyboardInput!.button(forKeyCode: .keyA)!.value > 0.5 {
                leftJoystick.x -= 1.0
            }
            if keyboard.keyboardInput!.button(forKeyCode: .keyS)!.value > 0.5 {
                leftJoystick.y -= 1.0
            }
            if keyboard.keyboardInput!.button(forKeyCode: .keyD)!.value > 0.5 {
                leftJoystick.x += 1.0
            }
        }
        
        // Move the camera
        if leftJoystick.x != 0.0 || leftJoystick.y != 0.0 {
            leftJoystick = normalize(leftJoystick)
        }
        self.camera.position += -cross(self.camera.direction, self.camera.up) * leftJoystick.x * dt
        self.camera.position +=        self.camera.direction                  * leftJoystick.y * dt
        
        // Rotate the camera
        self.camera.rotate(rotationAngles: self.rightJoystick)
        self.rightJoystick = simd_float2(0.0, 0.0)
        
        // Create command buffer
        let commandBuffer = self.commandQueue.makeCommandBuffer()!
        
        // Retrieve render pass descriptor and change the background color
        let renderPassDescriptor = view.currentRenderPassDescriptor!
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.416, green: 0.636, blue: 0.722, alpha: 1.0)
        renderPassDescriptor.depthAttachment.clearDepth = 1.0
        
        // Create render command encoder
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        
        // Bind render pipeline state
        renderEncoder.setRenderPipelineState(self.renderPipelineState!)
        
        // Bind depth stencil state
        renderEncoder.setDepthStencilState(self.depthStencilState)
        
        // Discard back faces
        renderEncoder.setFrontFacing(.clockwise)
        renderEncoder.setCullMode(.back)
        
        // Bind vertex buffer
        renderEncoder.setVertexBuffer(self.vertexBuffer, offset: 0, index: 30)
        
        // Bind textures
        renderEncoder.setFragmentTexture(self.diffuseTexture, index: 0)
        renderEncoder.setFragmentTexture(self.specularTexture, index: 1)
        
        // Create the projection matrix
        var projectionMatrix = createPerspectiveMatrix(fov: toRadians(from: 45.0), aspectRatio: self.aspectRatio, nearPlane: 0.1, farPlane: 100.0)
        renderEncoder.setVertexBytes(&projectionMatrix, length: MemoryLayout.stride(ofValue: projectionMatrix), index: 0)
        
        // Create the view matrix
        var viewMatrix = self.camera.getViewMatrix()
        renderEncoder.setVertexBytes(&viewMatrix, length: MemoryLayout.stride(ofValue: viewMatrix), index: 1)
        
        // Upload view position
        renderEncoder.setFragmentBytes(&self.camera.position, length: MemoryLayout.stride(ofValue: self.camera.position), index: 0)
        
        // Create the model matrix
        var modelMatrix = matrix_identity_float4x4
        translateMatrix(matrix: &modelMatrix, position: simd_float3(0.0, 0.0, 0.0))
        rotateMatrix(matrix: &modelMatrix, rotation: simd_float3(0.0, toRadians(from: 60.0), 0.0))
        scaleMatrix(matrix: &modelMatrix, scale: simd_float3(1.0, 1.0, 1.0))
        renderEncoder.setVertexBytes(&modelMatrix, length: MemoryLayout.stride(ofValue: modelMatrix), index: 2)
        
        // Render
        renderEncoder.drawIndexedPrimitives(type: MTLPrimitiveType.triangle, indexCount: indices.count, indexType: MTLIndexType.uint16, indexBuffer: self.indexBuffer, indexBufferOffset: 0)
        
        // End encoding
        renderEncoder.endEncoding()
        
        // Retrieve drawable and present it to the screen
        let drawable = view.currentDrawable!
        commandBuffer.present(drawable)
            
        // Send our commands to the GPU
        commandBuffer.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        self.windowSize = size
        self.aspectRatio = Float(self.windowSize.width) / Float(self.windowSize.height)
    }
}
