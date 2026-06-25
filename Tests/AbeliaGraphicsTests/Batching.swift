import Testing
@testable import AbeliaGraphics

@Test
func `Blur Pass Batching`(){
    let layer = nonOverlapBlurGrid(w: 2, h: 2)
    var scheduler = RenderScheduler()
    let a = scheduler.schedule(root: layer)
    #expect(a.pass.dependencies.count == 1)
}

