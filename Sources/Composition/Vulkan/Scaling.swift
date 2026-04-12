struct ScalingInfo {
    let actualSize: SIMD2<UInt32>

    func mapBack(_ position: SIMD2<Float>) -> SIMD2<Int> {
        let normalized = (position + 1) / 2
        let x = normalized.x * Float(actualSize.x)
        let y = normalized.y * Float(actualSize.y)

        return SIMD2(Int(x.rounded()), Int(y.rounded()))
    }
}

// let say 1280 * 720 map to (-1, 1) * (-1, 1)
