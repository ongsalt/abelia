@preconcurrency import CVMA
import Foundation
import Wayland

final class SwapChain {
    let device: VkDevice
    var surfaceFormat: VkSurfaceFormatKHR
    var swapChain: VkSwapchainKHR
    var extent: VkExtent2D
    var images: [VkImage]
    var imageViews: [VkImageView]

    var fences: [VkFence]
    var presentSemaphores: [VkSemaphore]
    var renderSemaphore: [VkSemaphore]

    // TODO: stop doing mailbox
    let framesInFlightCount: Int = 1
    var frameIndex: Int = 0

    init(
        surface: VkSurfaceKHR,
        physicalDevice: VkPhysicalDevice,
        logicalDevice device: VkDevice,
        families: SelectedQueuesIndices,
        preferredSize: SIMD2<UInt32> = SIMD2(800, 600)
    ) {
        self.device = device
        let (swapChain, swapChainSurfaceFormat, extent) = Self.createSwapChain(
            surface: surface,
            physicalDevice: physicalDevice,
            logicalDevice: device,
            preferredSize: preferredSize,
            indices: families
        )

        self.swapChain = swapChain
        self.surfaceFormat = swapChainSurfaceFormat
        self.extent = extent

        images = Vulkan.getArray(of: VkImage?.self) { [device, swapChain] count, arr in
            vkGetSwapchainImagesKHR(device, swapChain, count, arr)
        }.unwrapPointer()

        imageViews = Self.createImageViews(
            device: device, swapChainImages: images, swapChainSurfaceFormat: swapChainSurfaceFormat)

        let c = Self.createFence(
            device: device, count: framesInFlightCount, swapChainImageCount: images.count)
        self.fences = c.fences
        self.presentSemaphores = c.present
        self.renderSemaphore = c.render
    }

    func acquireNextImage() -> (VkImage, VkImageView, UInt32) {
        var imageIndex: UInt32 = 0

        vkAcquireNextImageKHR(
            device, swapChain, UInt64.max, presentSemaphores[frameIndex], nil,
            &imageIndex
        ).expect("Cannot acquire next image")

        return (images[Int(imageIndex)], imageViews[Int(imageIndex)], imageIndex)
    }

    func waitForFence(frameIndex: Int) {
        var fence: VkFence? = fences[frameIndex]
        vkWaitForFences(device, 1, &fence, true, UInt64.max).unwrap()
        vkResetFences(device, 1, &fence).unwrap()
    }

    func resetFence(frameIndex: Int) {
        var fence: VkFence? = fences[frameIndex]
        vkResetFences(device, 1, &fence).unwrap()
    }

    func isFenceCompleted(frameIndex: Int) -> Bool {
        let fence = fences[frameIndex]
        let status = vkGetFenceStatus(device, fence)
        return status == VK_SUCCESS
        // vkResetFences(device, 1, &fence).unwrap()
    }

    consuming func destroy() {
        vkDestroySwapchainKHR(device, swapChain, nil)
    }

    deinit {
        destroy()
    }

    private static func chooseSwapSurfaceFormat(from availableFormats: [VkSurfaceFormatKHR])
        -> VkSurfaceFormatKHR
    {
        let format = availableFormats.first {
            $0.format == VK_FORMAT_B8G8R8A8_SRGB
                && $0.colorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR
        }

        if let format {
            Logger.info(.vulkan, "Picked \(format)")
        }

        return format ?? availableFormats[0]
    }

    // TODO: allow vsync toggle
    private static func chooseSwapPresentMode(from availablePresentModes: [VkPresentModeKHR])
        -> VkPresentModeKHR
    {
        // availablePresentModes.contains(VK_PRESENT_MODE_MAILBOX_KHR)
        //     ? VK_PRESENT_MODE_MAILBOX_KHR
        //     : VK_PRESENT_MODE_FIFO_KHR
        VK_PRESENT_MODE_FIFO_KHR
    }

    private static func chooseSwapExtent(
        capabilities: VkSurfaceCapabilitiesKHR, preferredSize: SIMD2<UInt32>
    )
        -> VkExtent2D
    {
        if capabilities.currentExtent.width != UInt32.max {
            return capabilities.currentExtent
        }

        let width = preferredSize.x
        let height = preferredSize.y

        let actualExtent = VkExtent2D(
            width: width.clamp(
                to: capabilities.minImageExtent.width...capabilities.maxImageExtent.width),
            height: height.clamp(
                to: capabilities.minImageExtent.height...capabilities.maxImageExtent.height)
        )

        return actualExtent
    }

    private static func createSwapChain(
        surface: VkSurfaceKHR,
        physicalDevice: VkPhysicalDevice,
        logicalDevice device: VkDevice,
        preferredSize: SIMD2<UInt32>,
        indices: SelectedQueuesIndices,
        oldSwapchain: VkSwapchainKHR? = nil
    ) -> (swapChain: VkSwapchainKHR, surfaceFormat: VkSurfaceFormatKHR, extent: VkExtent2D) {
        let supportDetails = SwapChainSupportDetails(
            physicalDevice: physicalDevice,
            surface: surface
        )

        let surfaceFormat = chooseSwapSurfaceFormat(from: supportDetails.formats)
        let presentMode = chooseSwapPresentMode(from: supportDetails.presentModes)
        let extent = chooseSwapExtent(
            capabilities: supportDetails.capabilities, preferredSize: preferredSize)

        // print(supportDetails.formats)
        let surfaceCaps = supportDetails.capabilities

        let queueFamilyIndices = [indices.graphicsFamily!, indices.presentFamily!].map {
            UInt32($0)
        }
        let swapChain = queueFamilyIndices.withUnsafeBufferPointer { queueFamilyIndices in
            let swapchainCI = Box(VkSwapchainCreateInfoKHR()) {
                $0.sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR
                $0.surface = surface
                $0.minImageCount = surfaceCaps.minImageCount
                $0.imageFormat = surfaceFormat.format
                $0.imageColorSpace = surfaceFormat.colorSpace
                $0.imageExtent = extent
                $0.imageArrayLayers = 1
                $0.imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT.rawValue
                $0.presentMode = presentMode

                $0.preTransform = supportDetails.capabilities.currentTransform
                $0.compositeAlpha = VK_COMPOSITE_ALPHA_PRE_MULTIPLIED_BIT_KHR
                $0.clipped = true

                if indices.graphicsFamily != indices.presentFamily {
                    $0.imageSharingMode = VK_SHARING_MODE_CONCURRENT
                    $0.queueFamilyIndexCount = 2
                    $0.pQueueFamilyIndices = queueFamilyIndices.baseAddress
                } else {
                    $0.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE
                    $0.queueFamilyIndexCount = 0  // Optional
                    $0.pQueueFamilyIndices = nil  // Optional
                }

                // TODO: specify this
                $0.oldSwapchain = oldSwapchain
            }

            var swapChain: VkSwapchainKHR? = VkSwapchainKHR(bitPattern: 0)
            vkCreateSwapchainKHR(device, swapchainCI.ptr, nil, &swapChain).expect(
                "Cannot create swapchain")

            return swapChain!
        }

        return (swapChain, surfaceFormat, extent)
    }

    private static func createImageViews(
        device: VkDevice, swapChainImages: [VkImage], swapChainSurfaceFormat: VkSurfaceFormatKHR
    ) -> [VkImageView] {
        var swapChainImageViews = Array(
            repeating: VkImageView(bitPattern: 0), count: swapChainImages.count)

        for (i, image) in swapChainImages.enumerated() {
            let createInfo = Box(VkImageViewCreateInfo()) {
                $0.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO
                $0.image = image
                $0.viewType = VK_IMAGE_VIEW_TYPE_2D
                $0.format = swapChainSurfaceFormat.format

                $0.components.r = VK_COMPONENT_SWIZZLE_IDENTITY
                $0.components.g = VK_COMPONENT_SWIZZLE_IDENTITY
                $0.components.b = VK_COMPONENT_SWIZZLE_IDENTITY
                $0.components.a = VK_COMPONENT_SWIZZLE_IDENTITY

                $0.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT.rawValue
                $0.subresourceRange.baseMipLevel = 0
                $0.subresourceRange.levelCount = 1
                $0.subresourceRange.baseArrayLayer = 0
                $0.subresourceRange.layerCount = 1
            }

            vkCreateImageView(device, createInfo.ptr, nil, &swapChainImageViews[i]).expect(
                "Cannot create image view")
        }

        return swapChainImageViews.map { $0! }
    }

    private static func createFence(device: VkDevice, count: Int, swapChainImageCount: Int) -> (
        fences: [VkFence], present: [VkSemaphore], render: [VkSemaphore]
    ) {
        var fenceCI = VkFenceCreateInfo(
            sType: VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
            pNext: nil,
            flags: VK_FENCE_CREATE_SIGNALED_BIT.rawValue
        )

        var semaphoreCI = VkSemaphoreCreateInfo(
            sType: VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
            pNext: nil,
            flags: 0
        )

        var fences = Array(repeating: VkFence(bitPattern: 0), count: count)
        var semaphores = Array(repeating: VkSemaphore(bitPattern: 0), count: count)
        var renderSemaphores = Array(
            repeating: VkSemaphore(bitPattern: 0), count: swapChainImageCount)

        for i in 0..<count {
            vkCreateFence(device, &fenceCI, nil, &fences[i]).expect("Cannot create fence")
            vkCreateSemaphore(device, &semaphoreCI, nil, &semaphores[i]).expect(
                "Cannot create semaphore")
        }

        for i in 0..<swapChainImageCount {
            vkCreateSemaphore(device, &semaphoreCI, nil, &renderSemaphores[i]).expect(
                "Cannot create semaphore")
        }

        return (
            fences.unwrapPointer(), semaphores.unwrapPointer(), renderSemaphores.unwrapPointer()
        )
    }
}
