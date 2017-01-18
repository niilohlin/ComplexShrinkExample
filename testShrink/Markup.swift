//
//  Markup.swift
//  testShrink
//
//  Created by Niil Öhlin on 2017-01-18.
//  Copyright © 2017 Niil Öhlin. All rights reserved.
//

import Foundation

// Default indentation for pretty printing.
fileprivate let tab = "  "

// Repeat String Int times.
func *(lhs: Int, rhs: String) -> String {
    var accumulator = ""
    for _ in 0..<lhs {
        accumulator += rhs
    }
    return accumulator
}

func *(lhs: String, rhs: Int) -> String {
    return rhs * lhs
}

struct Attribute {
    // Represents an attribute on a Markup tag.
    let name: String
    let value: String
    var stringValue: String {
        return "\(name)=\"\(value)\""
    }
}

extension Array {
    // Convenience "any" function. Returns true if any element satisfies the predicate.
    func any(_ f: @escaping (Element) -> Bool) -> Bool {
        for element in self {
            if f(element) {
                return true
            }
        }
        return false
    }
}

precedencegroup FunctionApplicationPrecedence {
    associativity: left
    lowerThan: NilCoalescingPrecedence
    higherThan: AssignmentPrecedence
}

// Function application operator. Like "pipe" in bash.
infix operator |>: FunctionApplicationPrecedence
func |><T,U> (left: T, right: @escaping (T) -> U ) -> U {
    return right(left)
}

indirect enum Markup {
    // A subset of html.
    case img([Attribute])
    case br([Attribute])
    case area([Attribute])
    case p([Attribute], [Markup])
    case div([Attribute], [Markup])
    case table([Attribute], [Markup])
    case a([Attribute], [Markup])
    case string(String)
    var stringValue: String {
        return "\n" + prettyPrint()
    }

    private func prettyPrint(depth: Int = 0) -> String {
        return depth * tab + {
            switch self {
            case .img(let attrs):
                let attrString = attrs.reduce("") {(attrStr, attr) in attrStr + " " + attr.stringValue}
                return "<img" + attrString + "/>"
            case .br(let attrs):
                let attrString = attrs.reduce("") {(attrStr, attr) in attrStr + " " + attr.stringValue}
                return "<br" + attrString + "/>"
            case .area(let attrs):
                let attrString = attrs.reduce("") {(attrStr, attr) in attrStr + " " + attr.stringValue}
                return "<area" +  attrString + "/>"
            case .p(let attrs, let tags):
                let attrString = attrs.reduce("") {(attrStr, attr) in attrStr + " " + attr.stringValue}
                let childStrings = tags.reduce("") { (tagStr, tag) in tagStr + tag.prettyPrint(depth: depth + 1) }
                return "<p" + attrString + ">\n" + childStrings + depth * tab + "</p>"
            case .div(let attrs, let tags):
                let attrString = attrs.reduce("") {(attrStr, attr) in attrStr + " " + attr.stringValue}
                let childStrings = tags.reduce("") { (tagStr, tag) in tagStr + tag.prettyPrint(depth: depth + 1) }
                return "<div" + attrString + ">\n" + childStrings + depth * tab + "</div>"
            case .table(let attrs, let tags):
                let attrString = attrs.reduce("") {(attrStr, attr) in attrStr + " " + attr.stringValue}
                let childStrings = tags.reduce("") { (tagStr, tag) in tagStr + tag.prettyPrint(depth: depth + 1) }
                return "<table" + attrString + ">\n" + childStrings + depth * tab + "</table>"
            case .a(let attrs, let tags):
                let attrString = attrs.reduce("") {(attrStr, attr) in attrStr + " " + attr.stringValue}
                let childStrings = tags.reduce("") { (tagStr, tag) in tagStr + tag.prettyPrint(depth: depth + 1) }
                return "<a" + attrString + ">\n" + childStrings + depth * tab + "</a>"
            case .string(let string):
                return Markup.escaping(string: string)
            }
        }() + "\n"

    }

    // True if any element in the markup tree has a printable string.
    var isText: Bool {
        switch self {
        case .p(_, let children):
            return children.any { $0.isText }
        case .div(_, let children):
            return children.any { $0.isText }
        case .table(_, let children):
            return children.any { $0.isText }
        case .a(_, let children):
            return children.any { $0.isText }
        case .string(let string):
            return string.trimmingCharacters(in: .whitespacesAndNewlines) != ""
        default:
            return false
        }

    }

    // Escape common html characters.
    private static func escaping(string: String) -> String {
        return [("&", "&amp"),
                ("\"", "&quot"),
                ("'", "&#39"),
                (">", "&gt"),
                (">", "&lt")].reduce(string) { (escaped, pair) in escaped.replacingOccurrences(of: pair.0, with: pair.1) }
    }

    // The string representation of the markup.
    var printableString: String {
        guard let data = self.stringValue.data(using: .utf8) else {
            return ""
        }
        do {
            return try NSAttributedString(data: data, options: [NSDocumentTypeDocumentAttribute: NSHTMLTextDocumentType, NSCharacterEncodingDocumentAttribute: String.Encoding.utf8.rawValue], documentAttributes: nil).string
        } catch let error as NSError {
            print(error.localizedDescription)
            return ""
        }
    }
}
