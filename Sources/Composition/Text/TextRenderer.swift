// // import CFreeType
// import CPango

// // we need to nuke this 
// public class TextRenderer {
//     let fontmap: UnsafeMutablePointer<PangoFontMap>
//     let context: OpaquePointer
//     let layout: OpaquePointer

//     init() {
//         fontmap = pango_ft2_font_map_new()
//         context = pango_font_map_create_context(fontmap)
//         layout = pango_layout_new(context)
//     }

//     deinit {
//         g_object_unref(UnsafeMutableRawPointer(layout))
//         g_object_unref(UnsafeMutableRawPointer(context))
//         g_object_unref(UnsafeMutableRawPointer(fontmap))
//     }

//     public func measure(
//         text: String,
//         fontDescription: String = "Noto Sans 20",
//         width: Int? = nil,
//         height: Int? = nil,
//         wrap: PangoWrapMode = PANGO_WRAP_NONE
//     ) -> (ink: PangoRectangle, logical: PangoRectangle) {
//         let desc = PangoFontDescription(fontDescription)
//         return measure(text: text, fontDescription: desc, width: width, height: height, wrap: wrap)
//     }

//     public func measure(
//         text: String,
//         fontDescription: PangoFontDescription,
//         width: Int? = nil,
//         height: Int? = nil,
//         wrap: PangoWrapMode = PANGO_WRAP_NONE
//     ) -> (ink: PangoRectangle, logical: PangoRectangle) {
//         pango_layout_set_font_description(layout, fontDescription.desc)
//         pango_layout_set_text(layout, text, -1)

//         pango_layout_set_width(layout, width.map { Int32($0) * PANGO_SCALE } ?? -1)
//         pango_layout_set_height(layout, height.map { Int32($0) * PANGO_SCALE } ?? -1)
//         pango_layout_set_wrap(layout, wrap)

//         var ink = PangoRectangle()
//         var logical = PangoRectangle()
//         pango_layout_get_pixel_extents(layout, &ink, &logical)

//         return (ink, logical)
//     }

//     public func render(
//         _ text: String,
//         to buffer: UnsafeMutableBufferPointer<UInt8>,  // TODO: UnsafeMutableRawBufferPointer
//         width: Int32,
//         height: Int32,
//         fontDescription: String = "Noto Sans 20",
//         offsetX: Int32 = 0,
//         offsetY: Int32 = 0
//     ) -> Bool {
//         guard width > 0, height > 0 else { return false }
//         guard buffer.count >= width * height else { return false }  // its in byte so...

//         pango_layout_set_text(layout, text, -1)

//         // TODO: idk how expensive is this, but it will be call a lot with the same argument
//         let desc = PangoFontDescription(fontDescription)
//         pango_layout_set_font_description(layout, desc.desc)

//         // TODO: bound check

//         var bitmap = FT_Bitmap()
//         bitmap.width = numericCast(width)
//         bitmap.rows = numericCast(height)
//         bitmap.pitch = numericCast(width)
//         bitmap.buffer = buffer.baseAddress
//         bitmap.num_grays = 256
//         bitmap.pixel_mode = numericCast(FT_PIXEL_MODE_GRAY.rawValue)

//         pango_ft2_render_layout(&bitmap, layout, offsetX, offsetY)
//         return true
//     }
// }
