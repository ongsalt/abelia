all: shaders

shaders:
	slangc Sources/EmaCore/Resources/Shaders/composite.slang -target spirv -profile spirv_1_3 -emit-spirv-directly -fvk-use-entrypoint-name -entry vertMain -entry fragMain -o Sources/EmaCore/Generated/Resources/Shaders/composite.spv
	slangc Sources/EmaCore/Resources/Shaders/triangle.slang -target spirv -profile spirv_1_3 -emit-spirv-directly -fvk-use-entrypoint-name -entry vertMain -entry fragMain -o Sources/EmaCore/Generated/Resources/Shaders/triangle.spv
	