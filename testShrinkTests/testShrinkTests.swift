//
//  testShrinkTests.swift
//  testShrinkTests
//
//  Created by Niil Öhlin on 2017-01-18.
//  Copyright © 2017 Niil Öhlin. All rights reserved.
//

import XCTest
import SwiftCheck
import Foundation

@testable import testShrink

// Produce a string with easy to read characters.
let niceString: Gen<String> = Gen<Character>.fromElements(in: "a"..."z").proliferate.map {String.init($0)}

// Used to weight different outcomes when generating random values.
let successRate = 5

// Shorthand to frequency.
func fromWithFrequency<T: Arbitrary>(_ s: [(Int, T)]) -> Gen<T> {
    return Gen<T>.frequency(s.map { ($0.0, Gen<T>.pure($0.1)) })
}

extension Attribute: Arbitrary {
    public static var arbitrary: Gen<Attribute> {
        return Gen<Attribute>.compose { c in
            let name = niceString.suchThat { $0 != ""} |> c.generate
            let value = niceString |> c.generate
            return Attribute(name: name, value: value)
        }
    }

    // By default do not produce more than 3 attributes.
    static var arbitraryAttributes: Gen<[Attribute]> {
        return Gen<[Attribute]>.compose { c in
            let size = (0, 3) |> Gen<Int>.choose |> c.generate
            return Attribute.arbitrary.proliferate(withSize: size) |> c.generate
        }

    }

    // This should probably use the cartesian product of names and values but the returnvalue became insanely big.
    public static func shrink(_ attr: Attribute) -> [Attribute] {
        let names = String.shrink(attr.name)
        let values = String.shrink(attr.value)
        return zip(names, values).sorted { (pair1, pair2) -> Bool in
            return pair1.0.lengthOfBytes(using: .utf8) + pair1.1.lengthOfBytes(using: .utf8) < pair2.0.lengthOfBytes(using: .utf8) + pair2.1.lengthOfBytes(using: .utf8)
        }.map(Attribute.init)
    }
}

// This is implemented because of a recomendation here: https://hackage.haskell.org/package/QuickCheck-2.9.2/docs/Test-QuickCheck.html#v:arbitrary
// It still produces a _very_ large list.
func shrinkListPair<T: Arbitrary, G: Arbitrary>(_ a: [T], _ b: [G]) -> [([T], [G])] {
    let xs = Array<T>.shrink(a)
    let ys = Array<G>.shrink(b)
    return xs.flatMap{ (x) in
        return [(x,  b)]
        } + ys.flatMap { (y) in
            return [(a,  y)]
    }
}


extension Markup: Arbitrary {
    public static var arbitrary: Gen<Markup> {
        // Default to depth of 4.
        return Gen<Markup>.compose { c in
            return 4 |> Markup.arbitraryChild |> c.generate
        }
    }

    // Return a generator of any tag. With respect to depth.
    private static func arbitraryChild(depth: Int) -> Gen<Markup> {
        return Gen<Markup>.compose { c in
            let options = [(successRate, arbitraryLeaf), (1, String.arbitrary.map(Markup.string))] + (depth > 0 ? [(successRate, arbitraryParent(depth: depth))] : [])
            return options |> Gen<Markup>.frequency |> c.generate
        }
    }

    // Return a generator of tags that have children.
    private static func arbitraryParent(depth: Int) -> Gen<Markup> {
        return Gen<Markup>.compose { c in
            let size = (0, 3) |> Gen<Int>.choose |> c.generate
            let children = arbitraryChild(depth: depth - 1).proliferate(withSize: size) |> c.generate
            let attributes = Attribute.arbitraryAttributes |> c.generate
            let options = [.p(attributes, children), .div(attributes, children),  a(attributes, children), .table(attributes, children)]
            return options |> Gen<String>.fromElements |> c.generate
        }
    }

    // Returnn a generator of tags without children.
    private static var arbitraryLeaf: Gen<Markup> {
        return Gen<Markup>.compose { c in
            let src = String.arbitrary |> c.generate
            let attributes = Attribute.arbitraryAttributes |> c.generate
            let imageAttributes = attributes + [Attribute(name: "src", value: src)]
            let options:[(Int, Markup)] = [(successRate, .img(imageAttributes)), (1, .br(attributes)), (1, .area(attributes))]
            return options |> fromWithFrequency |> c.generate
        }
    }

    // Ok so here is my problem. How should I implement this in the best way?
    public static func shrink(_ markup: Markup) -> [Markup] {
        return shrink1(markup)
    }

    // This seems like approach this should make the smallest list. But it still generates a very big list.
    public static func shrink1(_ markup: Markup) -> [Markup] {
        switch markup {
        case .img(let attrs):
            if attrs.count == 0 {
                return []
            }
            return [.img([])]
        case .br(let attrs):
            if attrs.count == 0 {
                return []
            }
            return [.br([])]
        case .area(let attrs):
            if attrs.count == 0 {
                return []
            }
            return [.area([])]
        case .p(let attrs, let tags):
            if attrs.count == 0 && tags.count == 0 {
                return []
            }
            return [.p([], [])] + tags.flatMap(Markup.shrink)
        case .div(let attrs, let tags):
            if attrs.count == 0 && tags.count == 0 {
                return []
            }
            return [.div([], [])] + tags.flatMap(Markup.shrink)
        case .table(let attrs, let tags):
            if attrs.count == 0 && tags.count == 0 {
                return []
            }
            return [.table([], [])] + tags.flatMap(Markup.shrink)
        case .a(let attrs, let tags):
            if attrs.count == 0 && tags.count == 0 {
                return []
            }
            return [.a([], [])] + tags.flatMap(Markup.shrink)
        case .string(let string):
            if string.lengthOfBytes(using: .utf8) == 0 {
                return []
            }
            return [.string("")] + String.shrink(string).map(Markup.string)
        }
    }

    // This approach uses the 'algorithm' described on https://hackage.haskell.org/package/QuickCheck-2.9.2/docs/Test-QuickCheck.html#v:arbitrary
    // This still creates huge lists. Maybe this approach works better in haskell because haskell is lazy?
    public static func shrink2(_ markup: Markup) -> [Markup] {
        switch markup {
        case .img(let attrs):
            if attrs.count == 0 {
                return []
            }
            let possibleAttr = Array<Attribute>.shrink(attrs).sorted { (attr1, attr2) in attr1.count < attr2.count }
            return [.img([])] + possibleAttr.map(Markup.img)
        case .br(let attrs):
            if attrs.count == 0 {
                return []
            }
            let possibleAttr = Array<Attribute>.shrink(attrs).sorted { (attr1, attr2) in attr1.count < attr2.count }
            return [.br([])] + possibleAttr.map(Markup.br)
        case .area(let attrs):
            if attrs.count == 0 {
                return []
            }
            let possibleAttr = Array<Attribute>.shrink(attrs).sorted { (attr1, attr2) in attr1.count < attr2.count }
            return [.area([])] + possibleAttr.map(Markup.area)
        case .p(let attrs, let tags):
            if attrs.count == 0 && tags.count == 0 {
                return []
            }
            let attrsAndTags = shrinkListPair(attrs, tags)
            return [.p([], [])] + attrsAndTags.map(Markup.p)
        case .div(let attrs, let tags):
            if attrs.count == 0 && tags.count == 0 {
                return []
            }
            let attrsAndTags = shrinkListPair(attrs, tags)
            return [.div([], [])] + attrsAndTags.map(Markup.div)
        case .table(let attrs, let tags):
            if attrs.count == 0 && tags.count == 0 {
                return []
            }
            let attrsAndTags = shrinkListPair(attrs, tags)
            return [.table([], [])] + attrsAndTags.map(Markup.table)
        case .a(let attrs, let tags):
            if attrs.count == 0 && tags.count == 0 {
                return []
            }
            let attrsAndTags = shrinkListPair(attrs, tags)
            return [.a([], [])] + attrsAndTags.map(Markup.a)
        case .string(let string):
            if string.lengthOfBytes(using: .utf8) == 0 {
                return []
            }
            return [.string("")] + String.shrink(string).map(Markup.string)
        }
    }

    // This is the naive approach. This was my first attempt. I tried a few more with this approach. 
    // For example generating the cartesian product between the attributes and tags. And one where I sorted them.
    // It did not work.
    public static func shrink3(_ markup: Markup) -> [Markup] {
        switch markup {
        case .img(let attrs):
            let possibleAttr = Array<Attribute>.shrink(attrs)
            return possibleAttr.map(Markup.img)
        case .br(let attrs):
            let possibleAttr = Array<Attribute>.shrink(attrs)
            return possibleAttr.map(Markup.br)
        case .area(let attrs):
            let possibleAttr = Array<Attribute>.shrink(attrs)
            return  possibleAttr.map(Markup.area)
        case .p(let attrs, let tags):
            let possibleAttributes = Array<Attribute>.shrink(attrs)
            let possibleTags = Array<Markup>.shrink(tags)
            return zip(possibleAttributes, possibleTags).map(Markup.p)
        case .div(let attrs, let tags):
            let possibleAttributes = Array<Attribute>.shrink(attrs)
            let possibleTags = Array<Markup>.shrink(tags)
            return zip(possibleAttributes, possibleTags).map(Markup.div)
        case .table(let attrs, let tags):
            let possibleAttributes = Array<Attribute>.shrink(attrs)
            let possibleTags = Array<Markup>.shrink(tags)
            return zip(possibleAttributes, possibleTags).map(Markup.table)
        case .a(let attrs, let tags):
            let possibleAttributes = Array<Attribute>.shrink(attrs)
            let possibleTags = Array<Markup>.shrink(tags)
            return zip(possibleAttributes, possibleTags).map(Markup.a)
        case .string(let string):
            return String.shrink(string).map(Markup.string)
        }
    }

    // Return the "size" of the markup tree. Used for sorting the Markups so it starts with the smallest tree and continues to the largest.
    var size: Int {
            switch self {
            case .img(let attrs):
                return attrs.count
            case .br(let attrs):
                return attrs.count
            case .area(let attrs):
                return attrs.count
            case .p(let attrs, let tags):
                return attrs.count + tags.reduce(0) { (sum, tag) in sum + tag.size }
            case .div(let attrs, let tags):
                return attrs.count + tags.reduce(0) { (sum, tag) in sum + tag.size }
            case .table(let attrs, let tags):
                return attrs.count + tags.reduce(0) { (sum, tag) in sum + tag.size }
            case .a(let attrs, let tags):
                return attrs.count + tags.reduce(0) { (sum, tag) in sum + tag.size }
            case .string(let string):
                return string.lengthOfBytes(using: .utf8)
            }
    }
}

class testShrinkTests: XCTestCase {

    func testPropertyThatFailsWithBadShrinking() {
        property("A failing property that takes a long time to shrink") <- forAll { (m: Markup) in
            return (!m.printableString.contains("s")).whenFail {
                print("failed with markup ", m.stringValue)
            }
        }
    }
    
}
