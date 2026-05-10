all: shaders

shaders:
	glslc Sources/Composition/Resources/Shaders/composite.frag -o Sources/Composition/Resources/Compiled/composite.frag.spv
	glslc Sources/Composition/Resources/Shaders/composite.vert -o Sources/Composition/Resources/Compiled/composite.vert.spv
