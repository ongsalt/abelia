.PHONY: all shaders wayland

all: shaders

shaders:
	glslc Sources/Composition/Resources/Shaders/composite.frag -o Sources/Composition/Resources/Compiled/composite.frag.spv
	glslc Sources/Composition/Resources/Shaders/composite.vert -o Sources/Composition/Resources/Compiled/composite.vert.spv

wayland:
	cd Sources/CWayland && \
	wayland-scanner private-code < /usr/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml > xdg-shell-protocol.c && \
	wayland-scanner client-header < /usr/share/wayland-protocols/stable/xdg-shell/xdg-shell.xml > xdg-shell-client-protocol.h && \
	wayland-scanner private-code < /usr/share/wayland-protocols/staging/xdg-toplevel-drag/xdg-toplevel-drag-v1.xml > xdg-toplevel-drag-v1-protocol.c && \
	wayland-scanner client-header < /usr/share/wayland-protocols/staging/xdg-toplevel-drag/xdg-toplevel-drag-v1.xml > xdg-toplevel-drag-v1-client-protocol.h
