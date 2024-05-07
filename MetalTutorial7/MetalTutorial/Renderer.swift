import Metal
import MetalKit
import GameController
import simd

struct Vertex {
    var position: simd_float3
    var texCoord: simd_float2
    var normal: simd_float3
}

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
    
    // Models
    var sponzaModel: Model?
    
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
        
        // Loading models
        let textureLoader = MTKTextureLoader(device: self.device)
        let sponzaURL = Bundle.main.url(forResource: "Sponza_Scene", withExtension: "usdz")!
        self.sponzaModel = Model()
        self.sponzaModel?.scale = simd_float3(repeating: 0.002)
        self.sponzaModel?.loadModel(device: device, url: sponzaURL, vertexDescriptor: vertexDescriptor, textureLoader: textureLoader)
        
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
        
        // Create the projection matrix
        var projectionMatrix = createPerspectiveMatrix(fov: toRadians(from: 45.0), aspectRatio: self.aspectRatio, nearPlane: 0.1, farPlane: 100.0)
        renderEncoder.setVertexBytes(&projectionMatrix, length: MemoryLayout.stride(ofValue: projectionMatrix), index: 0)
        
        // Create the view matrix
        var viewMatrix = self.camera.getViewMatrix()
        renderEncoder.setVertexBytes(&viewMatrix, length: MemoryLayout.stride(ofValue: viewMatrix), index: 1)
        
        // Upload view position
        renderEncoder.setFragmentBytes(&self.camera.position, length: MemoryLayout.stride(ofValue: self.camera.position), index: 0)
        
        // Render
        sponzaModel?.render(renderEncoder: renderEncoder)
        
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
