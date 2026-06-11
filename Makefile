all: shaders

shaders:
	slangc Sources/Abelia/Resources/composite.slang -target spirv -profile spirv_1_3 -emit-spirv-directly -fvk-use-entrypoint-name -o Sources/Abelia/Generated/Resources/composite.spv
# 	-entry vertMain -entry fragMain 
	