@preconcurrency import CVulkan
import Foundation

class ShaderModule {
  let buffer: UnsafeMutableRawBufferPointer
  let handle: VkShaderModule
  let device: GraphicsDevice

  init?(device: GraphicsDevice, filename: String) {
    self.device = device

    let url = Bundle.module.url(forResource: "Resources/Shaders/\(filename)", withExtension: "spv")!

    guard let shaderData = try? Data(contentsOf: url) else {
      return nil
    }

    buffer = UnsafeMutableRawBufferPointer.allocate(
      byteCount: shaderData.count, alignment: MemoryLayout<CChar>.alignment)
    shaderData.copyBytes(to: buffer)

    var shaderModule: VkShaderModule?
    var ci = VkShaderModuleCreateInfo(
      sType: VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
      pNext: nil,
      flags: 0,
      codeSize: buffer.count,
      pCode: buffer.assumingMemoryBound(to: UInt32.self).baseAddress
    )
    vkCreateShaderModule(device.handle, &ci, nil, &shaderModule).expect("Cant create shader module")

    self.handle = shaderModule!
  }

}
