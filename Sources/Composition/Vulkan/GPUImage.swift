@preconcurrency import CVMA
import Wayland

// its only for cpu rendered text for now
class GPUImage {
    let image: VkImage
    let allocation: VmaAllocation
    let mapped: UnsafeMutableRawPointer
    private let allocator: VmaAllocator

    init(
        allocator: VmaAllocator, image: VkImage, allocation: VmaAllocation,
        mapped: UnsafeMutableRawPointer
    ) {
        self.allocator = allocator
        self.image = image
        self.allocation = allocation
        self.mapped = mapped
    }

    static func text(vulkan: VulkanState, size: SIMD2<UInt>) -> GPUImage {
        var ci = with(VkImageCreateInfo()) {
            $0.sType = VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO
            $0.imageType = VK_IMAGE_TYPE_2D
            $0.extent.width = numericCast(size.x)
            $0.extent.height = numericCast(size.y)
            $0.extent.depth = 1
            $0.mipLevels = 1
            $0.arrayLayers = 1
            $0.format = VK_FORMAT_R8_UNORM
            $0.initialLayout = VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL
            $0.usage =
                VK_IMAGE_USAGE_TRANSFER_DST_BIT.rawValue | VK_IMAGE_USAGE_SAMPLED_BIT.rawValue
            // $0.format = VK_FORMAT_R8G8B8A8_SRGB
            // $0.tiling = VK_IMAGE_TILING_LINEAR

            // this was probably dealt with by pango already
            $0.samples = VK_SAMPLE_COUNT_1_BIT
        }

        var allocationCi = VmaAllocationCreateInfo(
            flags: VMA_ALLOCATION_CREATE_HOST_ACCESS_SEQUENTIAL_WRITE_BIT.rawValue
                | VMA_ALLOCATION_CREATE_HOST_ACCESS_ALLOW_TRANSFER_INSTEAD_BIT.rawValue
                | VMA_ALLOCATION_CREATE_MAPPED_BIT.rawValue,
            usage: VMA_MEMORY_USAGE_AUTO,
            requiredFlags: 0,
            preferredFlags: 0,
            memoryTypeBits: 0,
            pool: nil,
            pUserData: nil,
            priority: 0
        )

        var image: VkImage? = nil
        var allocation: VmaAllocation? = nil
        var mapped: UnsafeMutableRawPointer? = nil

        vmaCreateImage(vulkan.allocator, &ci, &allocationCi, &image, &allocation, nil)
        vmaMapMemory(vulkan.allocator, allocation!, &mapped)

        return GPUImage(
            allocator: vulkan.allocator,
            image: image!,
            allocation: allocation!,
            mapped: mapped!
        )
    }

    deinit {
        vmaUnmapMemory(allocator, allocation)
        vmaDestroyImage(allocator, image, allocation)
    }

}
