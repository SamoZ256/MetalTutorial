import MetalKit

struct Material {
    var diffuseTexture: MTLTexture?
    var specularTexture: MTLTexture?
    
    init(mdlMaterial: MDLMaterial?, textureLoader: MTKTextureLoader) {
        self.diffuseTexture  = loadTexture(.baseColor, mdlMaterial: mdlMaterial, textureLoader: textureLoader)
        self.specularTexture = loadTexture(.specular,  mdlMaterial: mdlMaterial, textureLoader: textureLoader)
    }
    
    func loadTexture(_ semantic: MDLMaterialSemantic, mdlMaterial: MDLMaterial?, textureLoader: MTKTextureLoader) -> MTLTexture? {
        guard let materialProperty = mdlMaterial?.property(with: semantic) else { return nil }
        guard let sourceTexture = materialProperty.textureSamplerValue?.texture else { return nil }
        
        return try? textureLoader.newTexture(texture: sourceTexture, options: nil)
    }
}

class Mesh {
    var mesh: MTKMesh
    var materials: [Material]
    
    init(mesh: MTKMesh, materials: [Material]) {
        self.mesh = mesh
        self.materials = materials
    }
}

class Model {
    var meshes = [Mesh]()
    
    var position = simd_float3(repeating: 0.0)
    var rotation = simd_float3(repeating: 0.0)
    var scale = simd_float3(repeating: 0.0)
    
    func loadModel(device: MTLDevice, url: URL, vertexDescriptor: MTLVertexDescriptor, textureLoader: MTKTextureLoader) {
        let modelVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(vertexDescriptor)
        
        // Tell the model loader what the attributes represent
        let attrPosition = modelVertexDescriptor.attributes[0] as! MDLVertexAttribute
        attrPosition.name = MDLVertexAttributePosition
        modelVertexDescriptor.attributes[0] = attrPosition
        
        let attrTexCoord = modelVertexDescriptor.attributes[1] as! MDLVertexAttribute
        attrTexCoord.name = MDLVertexAttributeTextureCoordinate
        modelVertexDescriptor.attributes[1] = attrTexCoord
        
        let attrNormal = modelVertexDescriptor.attributes[2] as! MDLVertexAttribute
        attrNormal.name = MDLVertexAttributeNormal
        modelVertexDescriptor.attributes[2] = attrNormal
        
        // load the model
        let bufferAllocator = MTKMeshBufferAllocator(device: device)
        let asset = MDLAsset(url: url, vertexDescriptor: modelVertexDescriptor, bufferAllocator: bufferAllocator)
        
        // Load data for textures
        asset.loadTextures()
        
        // Retrieve the meshes
        guard let (mdlMeshes, mtkMeshes) = try? MTKMesh.newMeshes(asset: asset, device: device) else {
            print("Failed to create meshes")
            return
        }
        
        self.meshes.reserveCapacity(mdlMeshes.count)
        
        // Create our meshes
        for (mdlMesh, mtkMesh) in zip(mdlMeshes, mtkMeshes) {
            var materials = [Material]()
            for mdlSubmesh in mdlMesh.submeshes as! [MDLSubmesh] {
                let material = Material(mdlMaterial: mdlSubmesh.material, textureLoader: textureLoader)
                materials.append(material)
            }
            let mesh = Mesh(mesh: mtkMesh, materials: materials)
            self.meshes.append(mesh)
        }
    }
    
    func render(renderEncoder: MTLRenderCommandEncoder) {
        // Create the model matrix
        var modelMatrix = matrix_identity_float4x4
        translateMatrix(matrix: &modelMatrix, position: self.position)
        rotateMatrix(matrix: &modelMatrix, rotation: toRadians(from: self.rotation))
        scaleMatrix(matrix: &modelMatrix, scale: self.scale)
        renderEncoder.setVertexBytes(&modelMatrix, length: MemoryLayout.stride(ofValue: modelMatrix), index: 2)
        
        for mesh in self.meshes {
            // Bind vertex buffer
            let vertexBuffer = mesh.mesh.vertexBuffers[0]
            renderEncoder.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: 30)
            for (submesh, material) in zip(mesh.mesh.submeshes, mesh.materials) {
                // Bind textures
                renderEncoder.setFragmentTexture(material.diffuseTexture, index: 0)
                renderEncoder.setFragmentTexture(material.specularTexture, index: 1)
                
                // Draw
                let indexBuffer = submesh.indexBuffer
                renderEncoder.drawIndexedPrimitives(type: MTLPrimitiveType.triangle, indexCount: submesh.indexCount, indexType: submesh.indexType, indexBuffer: indexBuffer.buffer, indexBufferOffset: 0)
            }
        }
    }
}
