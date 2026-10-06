@preconcurrency import CVulkan

public enum VulkanError: Error {
    case unexpectedResult(VkResult, operation: String?)
    case unsupportedAPIVersion(supported: UInt32)
    case incompatibleSurface
    case unsupportedSurface
    case noGraphicsDevice
}

extension VkResult {
    /// Throws unless the result is `VK_SUCCESS`.
    func expect(_ operation: String? = nil) throws(VulkanError) {
        guard self == VK_SUCCESS else {
            throw .unexpectedResult(self, operation: operation)
        }
    }

    /// Accepts success and positive status codes, throwing only for negative errors.
    /// Returns the status so callers can handle `VK_INCOMPLETE`, `VK_TIMEOUT`, etc.
    @discardableResult
    func expectNonNegative(_ operation: String? = nil) throws(VulkanError) -> VkResult {
        guard rawValue >= 0 else {
            throw .unexpectedResult(self, operation: operation)
        }
        return self
    }
}

extension Bool {
    var vk: VkBool32 {
        if self { VK_TRUE } else { VK_FALSE }
    }
}
