@preconcurrency import CVMA
import Foundation

/// Keep this alive until you are done with it
class Shader {
    let buffer: UnsafeMutableRawBufferPointer
    let shaderModule: VkShaderModule
    let device: VkDevice

    init(filename: String, device: VkDevice) throws {
        self.device = device

        let url = Bundle.module.url(forResource: "Compiled/\(filename)", withExtension: nil)!

        let shaderData = try Data(contentsOf: url)

        buffer = UnsafeMutableRawBufferPointer.allocate(
            byteCount: shaderData.count, alignment: MemoryLayout<CChar>.alignment)
        shaderData.copyBytes(to: buffer)

        // print(buffer.hexString)

        var shaderModule = VkShaderModule(bitPattern: 0)
        var ci = VkShaderModuleCreateInfo(
            sType: VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
            pNext: nil,
            flags: VkShaderModuleCreateFlags(),
            codeSize: buffer.count,
            pCode: buffer.assumingMemoryBound(to: UInt32.self).baseAddress
        )
        vkCreateShaderModule(device, &ci, nil, &shaderModule).expect("Cant create shader module")

        self.shaderModule = shaderModule!
    }

    func leak() -> Shader {
        Unmanaged.passRetained(self)
        return self
    }

    deinit {
        vkDestroyShaderModule(device, shaderModule, nil)
        buffer.deallocate()
    }
}
