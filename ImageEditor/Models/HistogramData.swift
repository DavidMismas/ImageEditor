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

    var isEmpty: Bool {
        red.allSatisfy { $0 == 0 }
            && green.allSatisfy { $0 == 0 }
            && blue.allSatisfy { $0 == 0 }
            && luma.allSatisfy { $0 == 0 }
    }
}
