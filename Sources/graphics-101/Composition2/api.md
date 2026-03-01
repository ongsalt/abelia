# Shader types
- Rounded rect (sdf)
    - Fill
        - Color
        - Texture
    - Shadow
    - Border (its sdf anyway)
- Path
- Effect
    - Blending, Image filter (blur, dither, ...)
    - We can output multiple regions into one layer because overlapped regions gonna be in another layer anyway

## Implications

- Layer wth `clip: true` gonna raster its children in am offscreen texture
- So is anything under blur (also composite filter)
    - So we need to put multiple layer into one texture
- (unrelated) Layer must handle animation or else we gonna need to relayout everyframe
- Blur and composite filter doest need to be in the same shader