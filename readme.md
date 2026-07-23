# Abelia
ui library??

> [!NOTE]
> Weird edge around shapes are not AA bug but a compositing bug. It wont happen for in app surface only the os when composite it.

# Features
- SDF drawing primitive with ops like union, intersect, onion. See (Inigo Quilez's article)[https://iquilezles.org/articles/distfunctions2d/].
- Offscreen pass for opacity group and effect group.
- no text yet cuz [text rendering hates you](https://faultlore.com/blah/text-hates-you/) 

# Dependencies

## Linux

- `fontconfig`

## Dev dependencies
- `slangc > v2026.12.1` (cuz it has weird `nonuniformExt` bug)

## Todo
- multiple border (-> outline + stroke)
- clipping stack
- allow 2d transform on sdf merging
- harfbuzz gpu 
- proper erf box shadow
- offthread animation