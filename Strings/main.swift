#!/usr/bin/swift

import Foundation

let sourceFileURL = URL(fileURLWithPath: CommandLine.arguments[1])
let destinationFileURL = URL(fileURLWithPath: CommandLine.arguments[2])

guard let data = FileManager.default.contents(atPath: sourceFileURL.path) else { exit(0) }
guard let text = String.init(data: data, encoding: .utf8) else { exit(0) }

let strings = text.components(separatedBy: ";\n")

extension String {
    var lowercasingFirstLetter: String {
        return prefix(1).lowercased() + dropFirst()
    }
}

struct LocalizableString: CustomStringConvertible {
    let index: Int
    let underlyingString: String

    var comment: String?
    var id: String?
    var translation: String?

    var functionName: String?
    var parameters: [Parameter]?

    var idAndTranslation: String?

    var parametersString: String {
        guard let parameters = self.parameters else { return "" }

        let result = parameters
            .map { $0.parameterString }
            .joined(separator: ", ")
        return result
    }

    init(index: Int, string: String) {
        self.underlyingString = string.trimmingCharacters(in: .whitespacesAndNewlines)
        self.index = index
    }

    var description: String {
        var result: String
        guard let id = self.id, let translation = self.translation, let comment = self.comment else {
            return "[Index: \(index)] Faulty string: \(underlyingString)"
        }
        result = "[\(index)]\nID: \(id)\nTRANSLATION: \(translation)\nCOMMENT: \(comment)"
        if let parameters = parameters {
            result = result + "\nPARAMETERS: \(String(describing: parameters))"
        }
        return result
    }

    var functionDefinition: String {
        let result = "    /**\n     * \(translation!)\n     */\n    static func \(functionName!)(\(parametersString)) -> String {\n        \(functionBody)\n    }\n"
        return result
    }

    var functionBody: String {
        var result: String
        let nsLocalizedStringCall = "NSLocalizedString(\"\(id!)\", comment: \"\(comment!)\")"
        if let parameters = parameters, !parameters.isEmpty {
            let arguments = parameters
                .map { $0.index.map { "param\($0 + 1)" } ?? "param" }
                .joined(separator: ", ")

            result = "return String(format: \(nsLocalizedStringCall), \(arguments))"
        } else {
            result = "return \(nsLocalizedStringCall)"
        }
        return result
    }
}

enum StringsError: Error {
    case cantExtractComment(LocalizableString)
    case invalidCommentPrefix(LocalizableString)
    case cantExtractId(LocalizableString)
    case missingId(LocalizableString)
    case missingTranslation(LocalizableString)
    case missingComment(LocalizableString)
    case collidingParameterFormatSpecifiers(LocalizableString)
    case invalidIdSyntax(LocalizableString, String)
}

struct Parameter: Comparable {
    static func < (lhs: Parameter, rhs: Parameter) -> Bool {
        guard let lhsIndex = lhs.index,
            let rhsIndex = rhs.index else { return true }
        return lhsIndex < rhsIndex
    }

    static let indexedStrings = Array(1...5)
        .map { "%\($0)$@" }

    static let indexedNumbers = Array(1...5)
        .map { "%\($0)$d" }

    static let nonIndexedStrings = ["%@"]
    static let nonIndexedNumbers = ["%d"]

    enum ParameterType {
        case number
        case string

        var typeString: String {
            switch self {
            case .number: return "Int"
            case .string: return "String"
            }
        }
    }

    let index: Int?
    let type: ParameterType

    func collides(with other: Parameter) -> Bool {
        guard let lhsIndex = self.index,
            let rhsIndex = other.index,
            lhsIndex != rhsIndex else { return true }
        return false
    }

    var parameterString: String {
        return "param\(index.map { String($0 + 1) } ?? ""): \(type.typeString)"
    }
}

extension String {
    func trimmingOccurencesOf(_ substring: String) -> String {
        var copy = self
        if let startingRange = copy.range(of: substring), startingRange.lowerBound == copy.startIndex {
            copy.removeSubrange(startingRange)
        }
        var reversedCopy = String(copy.reversed())
        let reversedSubstring = String(substring.reversed())
        if let startingRange = reversedCopy.range(of: reversedSubstring), startingRange.lowerBound == reversedCopy.startIndex {
            reversedCopy.removeSubrange(startingRange)
        }
        return String(reversedCopy.reversed())
    }

    func prefixParameter() -> Parameter? {
        for specifier in Parameter.nonIndexedStrings {
            if self.hasPrefix(specifier) { return .init(index: nil, type: .string) }
        }
        for specifier in Parameter.nonIndexedNumbers {
            if self.hasPrefix(specifier) { return .init(index: nil, type: .number) }
        }
        for (index, specifier) in Parameter.indexedStrings.enumerated() {
            if self.hasPrefix(specifier) { return .init(index: index, type: .string) }
        }
        for (index, specifier) in Parameter.indexedNumbers.enumerated() {
            if self.hasPrefix(specifier) { return .init(index: index, type: .number) }
        }
        return nil
    }
}

func verify(_ string: LocalizableString) -> LocalizableString? {
    guard string.underlyingString.contains("=") else { return nil }
    return string
}

func extractComment2(_ string: LocalizableString) throws -> LocalizableString {
    let components = string.underlyingString.components(separatedBy: "*/\n")
    guard components.count == 2 else { throw StringsError.cantExtractComment(string) }
    guard components[0].hasPrefix("/*") else { throw StringsError.invalidCommentPrefix(string) }

    var copy = string
    copy.comment = components[0]
        .trimmingCharacters(in: .whitespaces)
        .trimmingOccurencesOf("/*")
        .trimmingCharacters(in: .whitespaces)
        .components(separatedBy: .newlines)
        .first!
        .replacingOccurrences(of: "\"", with: "'")

    copy.idAndTranslation = components[1]
    return copy
}

func extractId(_ string: LocalizableString) throws -> LocalizableString {
    guard let components = string.idAndTranslation?.components(separatedBy: "\" = \""),
        components.count == 2
        else { throw StringsError.cantExtractId(string) }

    var copy = string
    copy.id = components[0]
        .trimmingCharacters(in: .whitespaces)
        .trimmingOccurencesOf("\"")
        .trimmingCharacters(in: .whitespaces)

    copy.translation = components[1]
        .trimmingCharacters(in: .whitespaces)
        .trimmingOccurencesOf("\"")
        .trimmingCharacters(in: .whitespaces)
    return copy
}

func parseParameters(string: LocalizableString) throws -> LocalizableString {
    guard var translation = string.translation else { throw StringsError.missingTranslation(string) }

    var paramaters = [Parameter]()
    repeat {
        if let newParameter = translation.prefixParameter() {
            if paramaters.isEmpty {
                paramaters.append(newParameter)
           } else if (paramaters.filter { (param) -> Bool in newParameter.collides(with: param) }.isEmpty) {
                paramaters.append(newParameter)
            } else {
                throw StringsError.collidingParameterFormatSpecifiers(string)
            }
        }
        translation = String(translation.dropFirst())
    } while !translation.isEmpty

    var copy = string

    if !paramaters.isEmpty {
        copy.parameters = paramaters.sorted()
    }
    return copy
}

func generateFunctionName(string: LocalizableString) throws -> LocalizableString {
    guard let id = string.id else { throw StringsError.missingId(string) }

    let functionName = id.camelCased(maxWords: 10)
    if let _ = functionName.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) {
            throw StringsError.invalidIdSyntax(string, functionName)
    }

    var copy = string
    copy.functionName = functionName

    return copy
}

extension String {
    func camelCased(maxWords: Int) -> String {
        var components = [String]()

        let allowedCharacterSet = CharacterSet(charactersIn: "qwertyuioplkjhgfdsazxcvbnmQWERTYUIOPLKJHGFDSAZXCVBNM0123456789-.")

        if let _ = self.rangeOfCharacter(from: allowedCharacterSet.inverted) {
            // Id has the same format as the translation, e.g. New members get %1$d days trial period for free.
            let sanitized = self
                .replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: "")
                .replacingOccurrences(of: "'", with: "")
                .replacingOccurrences(of: "?", with: "")
                .replacingOccurrences(of: "!", with: "")
                .replacingOccurrences(of: ":", with: "")
                .replacingOccurrences(of: "/", with: "")

            var separators = CharacterSet.whitespaces
            separators.formUnion(CharacterSet.alphanumerics.inverted)

            components = sanitized
                .components(separatedBy: separators)
                .prefix(maxWords)
                .map { $0.capitalized }

        } else {
            // Id has the 'new' format, e.g. end-rental.label.distance-to-drop-off
        components = self
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
            .components(separatedBy: " ")
        }

        let camelCased = components
            .joined(separator: "")
            .replacingOccurrences(of: " ", with: "")
            .lowercasingFirstLetter

        return camelCased
    }


}

do {
    let localizableStrings = try strings.enumerated()
        .map(LocalizableString.init(index:string:))
        .compactMap(verify)
        .map(extractComment2)
        .map(extractId)
        .map(parseParameters)
        .map(generateFunctionName)

    var result = "/**\n * This is an auto-generated file. Do not modify manually.\n "
    result.append("import Foundation\n\n")

    result.append("struct Strings {\n")

    let functions = localizableStrings
        .map { $0.functionDefinition }
        .joined(separator: "\n")

    result.append(functions)

    result.append("}\n")

    guard let data = result.data(using: .utf8) else { fatalError("Can't convert output to data") }
    do {
        try data.write(to: destinationFileURL)
    } catch {
        fatalError("Can't write at destination URL")
    }

} catch {
    print(error)
}

//print(prefix)

//let results = strings.compactMap(analyze)
//let comments = strings.compactMap(extractComment)
//
//print("struct Strings {")
//let zipped = Array(zip(results, comments))
//zipped.forEach {
//    print("/// \($0.0[2])")
//    print("static func \($0.0[0])() -> String {")
//    print("return NSLocalizedString(\"\($0.0[1])\", comment: \"\($0.1)\")")
//    print("}")
//    print("")
//}
//print("}")


