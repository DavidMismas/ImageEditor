import Foundation
import simd

enum LUTParseError: LocalizedError {
    case invalidFormat
    case unsupportedCubeDimension
    case missingCubeData
    case malformedLine(String)

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "The selected LUT is not a valid .cube file."
        case .unsupportedCubeDimension:
            return "Only 3D .cube LUTs are supported."
        case .missingCubeData:
            return "The LUT is missing color cube data."
        case .malformedLine(let line):
            return "Malformed LUT line: \(line)"
        }
    }
}

struct LUTParser {
    func parse(at url: URL) throws -> LUTPreset {
        let contents = try String(contentsOf: url, encoding: .utf8)
        let lines = contents.components(separatedBy: .newlines)

        var title = url.deletingPathExtension().lastPathComponent
        var dimension = 0
        var domainMin = SIMD3<Float>(repeating: 0)
        var domainMax = SIMD3<Float>(repeating: 1)
        var cubeValues: [Float] = []
        var expectedEntryCount: Int?

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("#") else {
                continue
            }

            if line.hasPrefix("TITLE") {
                title = line.replacingOccurrences(of: "TITLE", with: "")
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                continue
            }

            if line.hasPrefix("LUT_1D_SIZE") {
                throw LUTParseError.unsupportedCubeDimension
            }

            if line.hasPrefix("LUT_3D_SIZE") {
                let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                guard components.count == 2, let parsedDimension = Int(components[1]), parsedDimension > 1 else {
                    throw LUTParseError.malformedLine(line)
                }
                dimension = parsedDimension
                expectedEntryCount = parsedDimension * parsedDimension * parsedDimension
                continue
            }

            if line.hasPrefix("DOMAIN_MIN") {
                domainMin = try parseVector(line)
                continue
            }

            if line.hasPrefix("DOMAIN_MAX") {
                domainMax = try parseVector(line)
                continue
            }

            let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard components.count == 3 else {
                throw LUTParseError.malformedLine(line)
            }

            guard expectedEntryCount != nil else {
                throw LUTParseError.invalidFormat
            }

            guard let red = Float(components[0]),
                  let green = Float(components[1]),
                  let blue = Float(components[2]) else {
                throw LUTParseError.malformedLine(line)
            }

            cubeValues.append(red)
            cubeValues.append(green)
            cubeValues.append(blue)
            cubeValues.append(1)

            if let expectedEntryCount, cubeValues.count / 4 > expectedEntryCount {
                throw LUTParseError.malformedLine(line)
            }
        }

        guard dimension > 0 else {
            throw LUTParseError.invalidFormat
        }

        guard cubeValues.count == dimension * dimension * dimension * 4 else {
            throw LUTParseError.missingCubeData
        }

        let cubeData = cubeValues.withUnsafeBufferPointer { Data(buffer: $0) }
        return LUTPreset(
            id: UUID(),
            name: title,
            url: url.standardizedResolvedFileURL,
            dimension: dimension,
            cubeData: cubeData,
            domainMin: domainMin,
            domainMax: domainMax
        )
    }

    private func parseVector(_ line: String) throws -> SIMD3<Float> {
        let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard components.count == 4,
              let x = Float(components[1]),
              let y = Float(components[2]),
              let z = Float(components[3]) else {
            throw LUTParseError.malformedLine(line)
        }

        return SIMD3<Float>(x, y, z)
    }
}
