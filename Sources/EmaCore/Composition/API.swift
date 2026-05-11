// // recreate swapchain -> mark only top level

// private func compositorStartup() {
//   createCompositionPipeline()
//   createEffectPipeline()
//   createBackingTextures()
//   createLayerStorage()
//   create
// }

// private func renderLoop() {

//   while root.dirty {
//     let image: SwapChainImage = await swapChain.getImage()
//     let batches: [Any] = computeBatches(root)

//     // traverse layer to find which need its SSBO update

//     // per renderRoot
//     // each batch have its own renderTexture (2 each)
//     var phases: [Int : PriorityQueue<Phase>] = [:]
//     for batch in batches {
//       for (index, phase) in batch.phases.enumerated() {
//         phases[index, default: []].append(phase, priority: phase.approximatedRenderingCost)
//       }
//     }

//     commandQueue.add(phase) // sorted

//     commandQueue.add(.wait(rootLayer, transitionTo: .present))

//     image.present()
//   }
// }
