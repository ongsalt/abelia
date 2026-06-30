all: shaders

shaders:
	slangc Sources/AbeliaGraphics/Resources/composite.slang -target spirv -profile spirv_1_4 -capability SPV_EXT_descriptor_indexing -emit-spirv-directly -fvk-use-entrypoint-name -o Sources/AbeliaGraphics/Generated/Resources/composite.spv
	spirv-val Sources/AbeliaGraphics/Generated/Resources/composite.spv --relax-block-layout --target-env vulkan1.3

	