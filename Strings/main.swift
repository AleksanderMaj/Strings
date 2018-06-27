#!/usr/bin/swift

import Foundation

let fileURL = URL(fileURLWithPath: CommandLine.arguments[1])

guard let data = FileManager.default.contents(atPath: fileURL.path) else { exit(0) }
guard let text = String.init(data: data, encoding: .utf8) else { exit(0) }

let strings = text.components(separatedBy: .newlines)

extension String {
    var lowercasingFirstLetter: String {
        return prefix(1).lowercased() + dropFirst()
    }
}

func analyze(_ string: String) -> [String]? {
    guard string.contains("\" = \"") else { return nil }
    var mutableString = string

    if let initialRange = mutableString.range(of: "\"") {
        let removeRange = mutableString.startIndex..<initialRange.upperBound
        mutableString.removeSubrange(removeRange)
    }

    if let closingRange = mutableString.range(of: "\";") {
        let removeRange = closingRange.lowerBound..<mutableString.endIndex
        mutableString.removeSubrange(removeRange)
    }

    let components = mutableString.components(separatedBy: "\" = \"")

    let camelCasedKey = components[0]
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
            .replacingOccurrences(of: " ", with: "")
            .lowercasingFirstLetter

    return [camelCasedKey, components[0], components[1]]
}

let result = strings.compactMap(analyze)
print("public enum Strings {")
result.forEach {
    print("public static func \($0[0])() -> String {")
    print("return NSLocalizedString(\"\($0[1])\", comment: \"\")")
    print("}")
}
print("}")


