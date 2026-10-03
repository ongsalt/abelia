import Testing
@testable import AbeliaGraphics

@Test
func vulkanInitialization() throws {
    let vulkanInstance = try VulkanInstance()
    let device = try vulkanInstance.requestDevice()
}

