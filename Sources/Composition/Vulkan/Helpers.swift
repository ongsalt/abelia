@preconcurrency import CVulkan
import Pointer

extension VkBool32: @retroactive ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) {
        self =
            if value {
                VK_TRUE
            } else {
                VK_FALSE
            }
    }

    public typealias BooleanLiteralType = Bool
}

extension VkBool32 {
    func isTrue() -> Bool {
        self == 1
    }
}

extension VkResult {
    func isOk() -> Bool {
        self == VK_SUCCESS
    }

    func expect(_ message: String) {
        if self.rawValue < 0 {
            let m = "\(message), code: \(self.rawValue)"
            Log.error(.vulkan, "error code: \(self.rawValue)")
            fatalError(m)
        }
        if self != VK_SUCCESS {
            Log.warn(.vulkan, "Not VK_SUCCESS: \(self.rawValue)")
        }
    }

    func unwrap() {
        expect("unwrap failed")
    }

    func unwrapOrElse<E>(_ block: () throws(E) -> Void) throws(E) {
        if self.rawValue < 0 {
            try block()
        }
        if self != VK_SUCCESS {
            Log.warn(.vulkan, "Not VK_SUCCESS: \(self.rawValue)")
        }
    }

    func throwing() throws(VulkanError) {
        if self.rawValue < 0 {
            throw VulkanError(code: self)
        }
    }

    struct VulkanError: Error {
        let code: VkResult
    }
}

struct Vulkan {
    static func makeVersion(major: UInt32, minor: UInt32, patch: UInt32) -> UInt32 {
        return (major << 22) | (minor << 12) | patch
    }

    static func makeApiVersion(variant: UInt32, major: UInt32, minor: UInt32, patch: UInt32)
        -> UInt32
    {
        return (variant << 29) | (major << 22) | (minor << 12) | patch
    }

    static let apiVersion1_0 = makeApiVersion(variant: 0, major: 1, minor: 0, patch: 0)
    static let apiVersion1_3 = makeApiVersion(variant: 0, major: 1, minor: 3, patch: 0)
    static let apiVersion = apiVersion1_3

    static func getArray<T>(
        default defaultValue: T,
        _ fn: (UnsafeMutablePointer<UInt32>, UnsafeMutablePointer<T>?) -> VkResult
    )
        -> [T]
    {
        var count: UInt32 = 0
        var array: [T] = []
        fn(&count, nil)

        array = Array(repeating: defaultValue, count: Int(count))
        fn(&count, &array)

        return array
    }

    static func getArray<T>(
        of: T.Type, _ fn: (UnsafeMutablePointer<UInt32>, UnsafeMutablePointer<T>?) -> VkResult
    ) -> [T] {
        return getArray(default: createZeroedStruct(of: T.self), fn)
    }

    static func printAvailableExtension() {
        var count: UInt32 = 0
        vkEnumerateInstanceExtensionProperties(nil, &count, nil)

        var extensions = Array(
            repeating: VkExtensionProperties(), count: Int(count))
        vkEnumerateInstanceExtensionProperties(nil, &count, &extensions)

        for var p in extensions {
            let name = String(cStringPointer: &p)
            print(name)
        }
    }

    static func printAvailableDeviceExtension(physicalDevice: VkPhysicalDevice) {
        let extensions = Vulkan.getArray(of: VkExtensionProperties.self) { count, arr in
            vkEnumerateDeviceExtensionProperties(physicalDevice, nil, count, arr)
        }

        for var p in extensions {
            let name = String(cStringPointer: &p)
            print(name)
        }
    }

    static func printAvailableLayers() {
        var count: UInt32 = 0
        vkEnumerateInstanceLayerProperties(&count, nil)

        var extensions = Array(
            repeating: VkLayerProperties(), count: Int(count))
        vkEnumerateInstanceLayerProperties(&count, &extensions)

        for var p in extensions {
            let name = String(cStringPointer: &p)
            print(name)
        }
    }

    static func create<T>(fn: (UnsafeMutablePointer<T>) -> VkResult) -> T {
        let ptr = UnsafeMutablePointer<T>.allocate(capacity: 1)
        fn(ptr).expect("Cannot create \(T.self)")
        return ptr.pointee
    }

}

struct SwapChainSupportDetails {
    let capabilities: VkSurfaceCapabilitiesKHR
    let formats: [VkSurfaceFormatKHR]
    let presentModes: [VkPresentModeKHR]

    init(physicalDevice device: VkPhysicalDevice, surface: VkSurfaceKHR) {
        var capabilities = VkSurfaceCapabilitiesKHR()
        vkGetPhysicalDeviceSurfaceCapabilitiesKHR(device, surface, &capabilities)

        let formats = Vulkan.getArray(of: VkSurfaceFormatKHR.self) { count, arr in
            vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, count, arr)
        }

        let presentModes = Vulkan.getArray(of: VkPresentModeKHR.self) { count, modes in
            vkGetPhysicalDeviceSurfacePresentModesKHR(
                device, surface, count, modes)
        }

        self.capabilities = capabilities
        self.formats = formats
        self.presentModes = presentModes
    }
}

extension Array where Element == OpaquePointer? {
    func unwrapPointer() -> [OpaquePointer] {
        self.map { $0! }
    }
}

extension UnsafeMutableRawBufferPointer {
    var hexString: String {
        self.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}

extension VkBufferUsageFlagBits {
    static func | (lhs: VkBufferUsageFlagBits, rhs: VkBufferUsageFlagBits) -> VkBufferUsageFlagBits
    {
        VkBufferUsageFlagBits(lhs.rawValue | rhs.rawValue)
    }
}

extension VkExtent2D {
    var simd2: SIMD2<UInt32> {
        SIMD2(self.width, self.height)
    }
}

extension SIMD2 where Scalar == UInt32 {
    var extent2d: VkExtent2D {
        VkExtent2D(width: x, height: y)
    }
    
    var extent3d: VkExtent3D {
        VkExtent3D(width: x, height: y, depth: 1)
    }
}
