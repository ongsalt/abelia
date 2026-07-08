// import WinSDK

// public class DXGISurface: SurfaceProtocol {
//     public typealias Texture = DXGISurfaceTexture
//     let hwnd: HWND

//     init(hwnd: HWND) {
//       self.hwnd = hwnd
//     }

//     public func configure(_ configuration: SurfaceConfiguration) throws {
        
//     }

//     public func acquireCurrentTexture(signalling semaphore: Semaphore) throws -> DXGISurfaceTexture {

//     }

// }

// public struct DXGISurfaceTexture: SurfaceTextureProtocol {
//     var texture: ImageAndView { 
//       fatalError()
//     }
//     var renderCompletedSemaphore: Semaphore { 
//       fatalError()
//     }
//     var imageIndex: UInt32 { 
//       0
//     }

//     func preparePresent() -> GPUCommands {
//       GPUCommands {}
//     }
//     func prepareRender() -> GPUCommands {
//       GPUCommands {}
//     }

//     // call queue submit, implicitly wait for renderCompletedSemaphore: Semaphore
//     func present() throws {

//     }

// }