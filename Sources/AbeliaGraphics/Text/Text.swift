// There is like 6 million problem to solve to get good text rendering
// 
/// What we need to do
/// - load font somehow
/// - Measure w + h & Break lines -> PAIN, will do later,
/// - Pass that to Harfbuzz and get a glyph run
/// - write glyph data into a texel buffer
/// - read it in the shader