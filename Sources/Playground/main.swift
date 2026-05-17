import Ema

runApp {
  Row {
    Box(alignment: .center) {
      Box()
        .width(12)
        .height(300)
        .color(.white)
    }
    .fillMaxHeight()
    .width(300)
    .color(.blue)

    Column {
      Box()
        .width(100)
        .height(67)
        .color(.white)
    }
    .color(.red)

  }
  .fillMaxSize()
}
