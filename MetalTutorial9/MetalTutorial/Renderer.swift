import Metal
import MetalKit
import GameController
import simd

class Renderer: NSObject, MTKViewDelegate {
    // Metal objects
    var device: MTLDevice
    var commandQueue: MTLCommandQueue
    
    var depthStencilState: MTLDepthStencilState?
    
    // Passes
    var shadowPass: ShadowPass
    var mainPass: MainPass
    
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
        
        // Library
        let library = device.makeDefaultLibrary()!
        
        // Passes
        shadowPass = ShadowPass(device: self.device, library: library)
        mainPass = MainPass(device: self.device, library: library, view: metalKitView)
        
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
        self.sponzaModel?.loadModel(device: device, url: sponzaURL, vertexDescriptor: self.mainPass.vertexDescriptor, textureLoader: textureLoader)
        
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
        shadowPass.encode(commandBuffer: commandBuffer, depthStencilState: self.depthStencilState!, render: { (renderEncoder: MTLRenderCommandEncoder) in
            self.sponzaModel?.render(renderEncoder: renderEncoder, bindTextures: false)
        }, viewProjMatrix: &lightViewProjMatrix)
        
        mainPass.encode(commandBuffer: commandBuffer, view: view, depthStencilState: self.depthStencilState!, render: { (renderEncoder: MTLRenderCommandEncoder) in
            self.sponzaModel?.render(renderEncoder: renderEncoder, bindTextures: true)
        }, viewPosition: &self.camera.position, viewProjMatrix: &viewProjMatrix, lightViewProjMatrix: &lightViewProjMatrix, shadowMap: self.shadowPass.shadowMap)
        
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
