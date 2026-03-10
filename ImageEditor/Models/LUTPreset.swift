import Foundation
import simd

struct LUTPreset: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let url: URL
    let dimension: Int
    let cubeData: Data
    let domainMin: SIMD3<Float>
    let domainMax: SIMD3<Float>
}
