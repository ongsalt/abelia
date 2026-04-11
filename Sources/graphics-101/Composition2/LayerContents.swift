@preconcurrency import CVMA

protocol LayerContents {
    // we want to put an image in here somehow
    // func
    var vkImage: VkImage { get }
}

extension VkImage: LayerContents {
    var vkImage: VkImage {
        self
    }
}


func putLayerContent() {
    // create a view and put its in the sampler registry
}