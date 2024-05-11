import Metal
import MetalKit
import GameController
import simd

struct Vertex {
    var position: simd_float3
    var texCoord: simd_float2
    var normal: simd_float3
    var tangent: simd_float4
}

class Renderer: NSObject, MTKViewDelegate {
    // Metal objects
    var device: MTLDevice
    var commandQueue: MTLCommandQueue
    
    var shadowMap: MTLTexture
    
    var shadowSampler: MTLSamplerState
    
    var renderPipelineState: MTLRenderPipelineState?
    var shadowRenderPipelineState: MTLRenderPipelineState?
    
    var depthStencilState: MTLDepthStencilState?
    
    // Models
    var sponzaModel: Model?
    
    // Window size
    var windowSize: CGSize = CGSizeZero
    var aspectRatio: Float = 1.0
    
    // Camera
    var camera = Camera()
    
    // Light
    let lightDirection = simd_float3(0.436436, -0.872872, 0.218218)
    
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
        
        // Main
        let vertexDescriptor = MTLVertexDescriptor()
        
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
        
        vertexDescriptor.attributes[3].format = MTLVertexFormat.float4
        vertexDescriptor.attributes[3].offset = MemoryLayout.offset(of: \Vertex.tangent)!
        vertexDescriptor.attributes[3].bufferIndex = 30
        
        // Shadow
        let shadowVertexDescriptor = MTLVertexDescriptor()
        
        shadowVertexDescriptor.layouts[30].stride = MemoryLayout<Vertex>.stride
        shadowVertexDescriptor.layouts[30].stepRate = 1
        shadowVertexDescriptor.layouts[30].stepFunction = MTLVertexStepFunction.perVertex

        shadowVertexDescriptor.attributes[0].format = MTLVertexFormat.float3
        shadowVertexDescriptor.attributes[0].offset = MemoryLayout.offset(of: \Vertex.position)!
        shadowVertexDescriptor.attributes[0].bufferIndex = 30
        
        // Textures
        let shadowMapDescriptor = MTLTextureDescriptor()
        shadowMapDescriptor.pixelFormat = MTLPixelFormat.depth32Float
        shadowMapDescriptor.usage = [.shaderRead, .renderTarget]
        shadowMapDescriptor.width = 2048
        shadowMapDescriptor.height = 2048
        shadowMapDescriptor.storageMode = MTLStorageMode.private
        self.shadowMap = device.makeTexture(descriptor: shadowMapDescriptor)!
        
        // Samplers
        let shadowSamplerDescriptor = MTLSamplerDescriptor()
        shadowSamplerDescriptor.minFilter = .linear
        shadowSamplerDescriptor.magFilter = .linear
        shadowSamplerDescriptor.compareFunction = .less
        self.shadowSampler = device.makeSamplerState(descriptor: shadowSamplerDescriptor)!
        
        // Library
        let library = device.makeDefaultLibrary()!
        
        // Functions
        
        // Main
        let vertexFunction = library.makeFunction(name: "vertexFunction")!
        let fragmentFunction = library.makeFunction(name: "fragmentFunction")!
        
        // Shadow
        let shadowVertexFunction = library.makeFunction(name: "shadowVertexFunction")!
        let shadowFragmentFunction = library.makeFunction(name: "shadowFragmentFunction")!
        
        // Render pipeline state
        
        // Main
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
        
        // Shadow
        let shadowRenderPipelineStateDescriptor = MTLRenderPipelineDescriptor()
        shadowRenderPipelineStateDescriptor.vertexFunction = shadowVertexFunction
        shadowRenderPipelineStateDescriptor.fragmentFunction = shadowFragmentFunction
        shadowRenderPipelineStateDescriptor.vertexDescriptor = shadowVertexDescriptor
        shadowRenderPipelineStateDescriptor.depthAttachmentPixelFormat = self.shadowMap.pixelFormat
        do {
            self.shadowRenderPipelineState = try self.device.makeRenderPipelineState(descriptor: shadowRenderPipelineStateDescriptor)
        } catch {
            print("Failed to create shadow render pipeline state")
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
        self.sponzaModel?.scale = simd_float3(repeating: 0.004)
        self.sponzaModel?.loadModel(device: device, url: sponzaURL, vertexDescriptor: vertexDescriptor, textureLoader: textureLoader)
        
        // Time
        lastTime = Date().timeIntervalSince1970
        
        super.init()
    }
    
    func shadowPass(commandBuffer: MTLCommandBuffer, viewProjMatrix: inout float4x4) {
        // Create render pass descriptor
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.depthAttachment.texture = shadowMap
        renderPassDescriptor.depthAttachment.loadAction = .clear
        renderPassDescriptor.depthAttachment.storeAction = .store
        renderPassDescriptor.depthAttachment.clearDepth = 1.0
        
        // Create render command encoder
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
        
        // Bind render pipeline state
        renderEncoder.setRenderPipelineState(self.shadowRenderPipelineState!)
        
        // Bind depth stencil state
        renderEncoder.setDepthStencilState(self.depthStencilState)
        
        // Discard back faces
        renderEncoder.setFrontFacing(.clockwise)
        renderEncoder.setCullMode(.back)
        
        // Upload the view projection matrix
        renderEncoder.setVertexBytes(&viewProjMatrix, length: MemoryLayout.stride(ofValue: viewProjMatrix), index: 0)
        
        // Upload view position
        renderEncoder.setFragmentBytes(&self.camera.position, length: MemoryLayout.stride(ofValue: self.camera.position), index: 0)
        
        // Render
        self.sponzaModel?.render(renderEncoder: renderEncoder, bindTextures: false)
        
        // End encoding
        renderEncoder.endEncoding()
    }
    
    func mainPass(commandBuffer: MTLCommandBuffer, view: MTKView, viewProjMatrix: inout float4x4, lightViewProjMatrix: inout float4x4) {
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
        
        // Upload the view projection matrix
        renderEncoder.setVertexBytes(&viewProjMatrix, length: MemoryLayout.stride(ofValue: viewProjMatrix), index: 0)
        
        // Upload the light view projection
        renderEncoder.setFragmentBytes(&lightViewProjMatrix, length: MemoryLayout.stride(ofValue: lightViewProjMatrix), index: 1)
        
        // Upload view position
        renderEncoder.setFragmentBytes(&self.camera.position, length: MemoryLayout.stride(ofValue: self.camera.position), index: 0)
        
        // Bind the shadow map
        renderEncoder.setFragmentTexture(self.shadowMap, index: 0)
        renderEncoder.setFragmentSamplerState(self.shadowSampler, index: 0)
        
        // Render
        self.sponzaModel?.render(renderEncoder: renderEncoder, bindTextures: true)
        
        // End encoding
        renderEncoder.endEncoding()
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
        
        // Matrices
        
        // Main
        let projectionMatrix = createPerspectiveMatrix(fov: toRadians(from: 45.0), aspectRatio: self.aspectRatio, nearPlane: 0.1, farPlane: 100.0)
        let viewMatrix = self.camera.getViewMatrix()
        var viewProjMatrix = projectionMatrix * viewMatrix
        
        // Light
        let lightProjectionMatrix = createOrthogonalProjection(-10.0, 10.0, -10.0, 10.0, -25.0, 25.0)
        let lightViewMatrix = createViewMatrix(eyePosition: -lightDirection, targetPosition: simd_float3(repeating: 0.0), upVec: simd_float3(0.0, 1.0, 0.0))
        var lightViewProjMatrix = lightProjectionMatrix * lightViewMatrix
        
        // Passes
        shadowPass(commandBuffer: commandBuffer, viewProjMatrix: &lightViewProjMatrix)
        mainPass(commandBuffer: commandBuffer, view: view, viewProjMatrix: &viewProjMatrix, lightViewProjMatrix: &lightViewProjMatrix)
        
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
