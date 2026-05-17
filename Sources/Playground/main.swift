import Ema

runApp {
  Row {
    Box(alignment: .center) {
      Box()
        .width(12)
        .height(67)
    }
    .fillMaxHeight()
    .width(300)

    Column {
      Box()
        .width(100)
        .height(67)
    }

  }
  .fillMaxSize()
}
