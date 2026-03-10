import Foundation

struct ToneCurveInterpolator: Sendable {
    private let xValues: [Float]
    private let yValues: [Float]
    private let tangents: [Float]

    init(curve: CurvePointSet) {
        xValues = [0, 0.25, 0.5, 0.75, 1]
        yValues = curve.values.map { Float($0).clamped(to: 0...1) }
        tangents = ToneCurveInterpolator.computeTangents(xValues: xValues, yValues: yValues)
    }

    func sample(_ input: Float) -> Float {
        let x = input.clamped(to: 0...1)

        for index in 0..<(xValues.count - 1) where x <= xValues[index + 1] {
            return sampleSegment(index: index, x: x)
        }

        return yValues.last ?? x
    }

    private func sampleSegment(index: Int, x: Float) -> Float {
        let x0 = xValues[index]
        let x1 = xValues[index + 1]
        let y0 = yValues[index]
        let y1 = yValues[index + 1]
        let m0 = tangents[index]
        let m1 = tangents[index + 1]
        let h = max(x1 - x0, 0.0001)
        let t = ((x - x0) / h).clamped(to: 0...1)

        let h00 = (2 * t * t * t) - (3 * t * t) + 1
        let h10 = (t * t * t) - (2 * t * t) + t
        let h01 = (-2 * t * t * t) + (3 * t * t)
        let h11 = (t * t * t) - (t * t)

        return (h00 * y0) + (h10 * h * m0) + (h01 * y1) + (h11 * h * m1)
    }

    private static func computeTangents(xValues: [Float], yValues: [Float]) -> [Float] {
        let count = yValues.count
        guard count > 2 else {
            return Array(repeating: 1, count: count)
        }

        var segmentSlopes = Array(repeating: Float.zero, count: count - 1)
        for index in segmentSlopes.indices {
            let dx = max(xValues[index + 1] - xValues[index], 0.0001)
            segmentSlopes[index] = (yValues[index + 1] - yValues[index]) / dx
        }

        var tangents = Array(repeating: Float.zero, count: count)
        tangents[0] = endpointTangent(firstSlope: segmentSlopes[0], secondSlope: segmentSlopes[1])
        tangents[count - 1] = endpointTangent(firstSlope: segmentSlopes[count - 2], secondSlope: segmentSlopes[count - 3])

        for index in 1..<(count - 1) {
            let previousSlope = segmentSlopes[index - 1]
            let nextSlope = segmentSlopes[index]

            if previousSlope == 0 || nextSlope == 0 || previousSlope.sign != nextSlope.sign {
                tangents[index] = 0
                continue
            }

            let dxPrevious = xValues[index] - xValues[index - 1]
            let dxNext = xValues[index + 1] - xValues[index]
            let weightA = 2 * dxNext + dxPrevious
            let weightB = dxNext + 2 * dxPrevious
            tangents[index] = (weightA + weightB) / ((weightA / previousSlope) + (weightB / nextSlope))
        }

        return tangents
    }

    private static func endpointTangent(firstSlope: Float, secondSlope: Float) -> Float {
        let tangent = (2 * firstSlope) - secondSlope

        if tangent.sign != firstSlope.sign {
            return 0
        }

        if firstSlope.sign != secondSlope.sign && abs(tangent) > abs(3 * firstSlope) {
            return 3 * firstSlope
        }

        return tangent
    }
}
