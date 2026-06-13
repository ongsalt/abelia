all: shaders

shaders:
	slangc Sources/AbeliaGraphics/Resources/composite.slang -target spirv -profile spirv_1_3 -emit-spirv-directly -fvk-use-entrypoint-name -o Sources/AbeliaGraphics/Generated/Resources/composite.spv
	spirv-val Sources\AbeliaGraphics\Generated\Resources\composite.spv --relax-block-layout --target-env vulkan1.3
# 	slangc Sources/AbeliaGraphics/Resources/composite.slang -target spirv -profile spirv_1_3 -o Sources/AbeliaGraphics/Generated/Resources/composite.spv
# 	-entry vertMain -entry fragMain 

	