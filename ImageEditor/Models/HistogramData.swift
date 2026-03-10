import Foundation

struct HistogramData: Hashable, Sendable {
    static let defaultBinCount = 64

    var red: [Double]
    var green: [Double]
    var blue: [Double]
    var luma: [Double]

    static let empty = HistogramData(
        red: Array(repeating: 0, count: defaultBinCount),
        green: Array(repeating: 0, count: defaultBinCount),
        blue: Array(repeating: 0, count: defaultBinCount),
        luma: Array(repeating: 0, count: defaultBinCount)
    )
}
