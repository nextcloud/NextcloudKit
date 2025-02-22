// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2024 Marino Faggiana
// SPDX-License-Identifier: GPL-3.0-or-later
//
// This code derived from: http://basememara.com/creating-thread-safe-arrays-in-swift/

import Foundation

/// A thread-safe array.
public struct ThreadSafeArray<Element: Sendable>: Sendable {

    private var array = [Element]()

    public init() { }

    public init(_ array: [Element]) {
        self.init()
        self.array = array
    }
}

// MARK: - Properties

public extension ThreadSafeArray {

    /// The first element of the collection.
    var first: Element? {
        NSLock().perform { self.array.first }
    }

    /// The last element of the collection.
    var last: Element? {
        NSLock().perform { self.array.last }
    }

    /// The number of elements in the array.
    var count: Int {
        NSLock().perform { self.array.count }
    }

    /// A Boolean value indicating whether the collection is empty.
    var isEmpty: Bool {
        NSLock().perform { self.array.isEmpty }
    }

    /// A textual representation of the array and its elements.
    var description: String {
        NSLock().perform { self.array.description }
    }
}

// MARK: - Immutable

public extension ThreadSafeArray {

    /// Returns the first element of the sequence that satisfies the given predicate.
    ///
    /// - Parameter predicate: A closure that takes an element of the sequence as its argument and returns a Boolean value indicating whether the element is a match.
    /// - Returns: The first element of the sequence that satisfies predicate, or nil if there is no element that satisfies predicate.
    func first(where predicate: (Element) -> Bool) -> Element? {
        NSLock().perform { self.array.first(where: predicate) }
    }

    /// Returns the last element of the sequence that satisfies the given predicate.
    ///
    /// - Parameter predicate: A closure that takes an element of the sequence as its argument and returns a Boolean value indicating whether the element is a match.
    /// - Returns: The last element of the sequence that satisfies predicate, or nil if there is no element that satisfies predicate.
    func last(where predicate: (Element) -> Bool) -> Element? {
        NSLock().perform { self.array.last(where: predicate) }
    }

    /// Returns an array containing, in order, the elements of the sequence that satisfy the given predicate.
    ///
    /// - Parameter isIncluded: A closure that takes an element of the sequence as its argument and returns a Boolean value indicating whether the element should be included in the returned array.
    /// - Returns: An array of the elements that includeElement allowed.
    func filter(_ isIncluded: @escaping (Element) -> Bool) -> ThreadSafeArray {
        NSLock().perform { ThreadSafeArray(self.array.filter(isIncluded)) }
    }

    /// Returns the first index in which an element of the collection satisfies the given predicate.
    ///
    /// - Parameter predicate: A closure that takes an element as its argument and returns a Boolean value that indicates whether the passed element represents a match.
    /// - Returns: The index of the first element for which predicate returns true. If no elements in the collection satisfy the given predicate, returns nil.
    func index(where predicate: (Element) -> Bool) -> Int? {
        NSLock().perform { self.array.firstIndex(where: predicate) }
    }

    /// Returns the elements of the collection, sorted using the given predicate as the comparison between elements.
    ///
    /// - Parameter areInIncreasingOrder: A predicate that returns true if its first argument should be ordered before its second argument; otherwise, false.
    /// - Returns: A sorted array of the collection’s elements.
    func sorted(by areInIncreasingOrder: (Element, Element) -> Bool) -> ThreadSafeArray {
        NSLock().perform { ThreadSafeArray(self.array.sorted(by: areInIncreasingOrder)) }
    }

    /// Returns an array containing the results of mapping the given closure over the sequence’s elements.
    ///
    /// - Parameter transform: A closure that accepts an element of this sequence as its argument and returns an optional value.
    /// - Returns: An array of the non-nil results of calling transform with each element of the sequence.
    func map<ElementOfResult>(_ transform: @escaping (Element) -> ElementOfResult) -> [ElementOfResult] {
        NSLock().perform { self.array.map(transform) }
    }

    /// Returns an array containing the non-nil results of calling the given transformation with each element of this sequence.
    ///
    /// - Parameter transform: A closure that accepts an element of this sequence as its argument and returns an optional value.
    /// - Returns: An array of the non-nil results of calling transform with each element of the sequence.
    func compactMap<ElementOfResult>(_ transform: (Element) -> ElementOfResult?) -> [ElementOfResult] {
        NSLock().perform { self.array.compactMap(transform) }
    }

    /// Returns the result of combining the elements of the sequence using the given closure.
    ///
    /// - Parameters:
    ///   - initialResult: The value to use as the initial accumulating value. initialResult is passed to nextPartialResult the first time the closure is executed.
    ///   - nextPartialResult: A closure that combines an accumulating value and an element of the sequence into a new accumulating value, to be used in the next call of the nextPartialResult closure or returned to the caller.
    /// - Returns: The final accumulated value. If the sequence has no elements, the result is initialResult.
    func reduce<ElementOfResult>(_ initialResult: ElementOfResult, _ nextPartialResult: @escaping (ElementOfResult, Element) -> ElementOfResult) -> ElementOfResult {
        NSLock().perform { self.array.reduce(initialResult, nextPartialResult) }
    }

    /// Returns the result of combining the elements of the sequence using the given closure.
    ///
    /// - Parameters:
    ///   - initialResult: The value to use as the initial accumulating value.
    ///   - updateAccumulatingResult: A closure that updates the accumulating value with an element of the sequence.
    /// - Returns: The final accumulated value. If the sequence has no elements, the result is initialResult.
    func reduce<ElementOfResult>(into initialResult: ElementOfResult, _ updateAccumulatingResult: @escaping (inout ElementOfResult, Element) -> Void) -> ElementOfResult {
        NSLock().perform { self.array.reduce(into: initialResult, updateAccumulatingResult) }
    }

    /// Calls the given closure on each element in the sequence in the same order as a for-in loop.
    ///
    /// - Parameter body: A closure that takes an element of the sequence as a parameter.
    func forEach(_ body: (Element) -> Void) {
        NSLock().perform { self.array.forEach(body) }
    }

    /// Returns a Boolean value indicating whether the sequence contains an element that satisfies the given predicate.
    ///
    /// - Parameter predicate: A closure that takes an element of the sequence as its argument and returns a Boolean value that indicates whether the passed element represents a match.
    /// - Returns: true if the sequence contains an element that satisfies predicate; otherwise, false.
    func contains(where predicate: (Element) -> Bool) -> Bool {
        NSLock().perform { self.array.contains(where: predicate) }
    }

    /// Returns a Boolean value indicating whether every element of a sequence satisfies a given predicate.
    ///
    /// - Parameter predicate: A closure that takes an element of the sequence as its argument and returns a Boolean value that indicates whether the passed element satisfies a condition.
    /// - Returns: true if the sequence contains only elements that satisfy predicate; otherwise, false.
    func allSatisfy(_ predicate: (Element) -> Bool) -> Bool {
        NSLock().perform { self.array.allSatisfy(predicate) }
    }

    /// Returns the array
    ///
    /// - Returns: the array part.
    func getArray() -> [Element]? {
        NSLock().perform { self.array }
    }
}

// MARK: - Mutable

public extension ThreadSafeArray {

    /// Adds a new element at the end of the array.
    ///
    /// - Parameter element: The element to append to the array.
    mutating func append(_ element: Element) {
        NSLock().perform { self.array.append(element) }
    }

    /// Adds new elements at the end of the array.
    ///
    /// - Parameter element: The elements to append to the array.
    mutating func append(_ elements: [Element]) {
        NSLock().perform { self.array += elements }
    }

    /// Inserts a new element at the specified position.
    ///
    /// - Parameters:
    ///   - element: The new element to insert into the array.
    ///   - index: The position at which to insert the new element.
    mutating func insert(_ element: Element, at index: Int) {
        NSLock().perform { self.array.insert(element, at: index) }
    }

    /// Removes and returns the element at the specified position.
    ///
    /// - Parameters:
    ///   - index: The position of the element to remove.
    ///   - completion: The handler with the removed element.
    mutating func remove(at index: Int, completion: ((Element) -> Void)? = nil) {
        NSLock().perform { self.array.remove(at: index) }
    }

    /// Removes and returns the elements that meet the criteria.
    ///
    /// - Parameters:
    ///   - predicate: A closure that takes an element of the sequence as its argument and returns a Boolean value indicating whether the element is a match.
    ///   - completion: The handler with the removed elements.
    mutating func remove(where predicate: @escaping (Element) -> Bool) -> [Element] {
        return NSLock().perform {
            var elements = [Element]()
            while let index = self.array.firstIndex(where: predicate) {
                elements.append(self.array.remove(at: index))
            }
            return elements
        }
    }

    /// Removes all elements from the array.
    ///
    /// - Parameter keepingCapacity: Pass true to keep the existing capacity of the array after removing its elements. The default value is false.
    mutating func removeAll(keepingCapacity: Bool = false) {
        NSLock().perform { self.array.removeAll(keepingCapacity: keepingCapacity) }
    }
}

public extension ThreadSafeArray {

    /// Accesses the element at the specified position if it exists.
    ///
    /// - Parameter index: The position of the element to access.
    /// - Returns: optional element if it exists.
    subscript(index: Int) -> Element? {
        get {
            NSLock().perform {
                guard self.array.startIndex..<self.array.endIndex ~= index else { return nil }
                return self.array[index]
            }
        }
        set {
            guard let newValue = newValue else { return }
            NSLock().perform { self.array[index] = newValue }
        }
    }
}

// MARK: - Equatable

public extension ThreadSafeArray where Element: Equatable {

    /// Returns a Boolean value indicating whether the sequence contains the given element.
    ///
    /// - Parameter element: The element to find in the sequence.
    /// - Returns: true if the element was found in the sequence; otherwise, false.
    func contains(_ element: Element) -> Bool {
        NSLock().perform { self.array.contains(element) }
    }
}

// MARK: - Infix operators

public extension ThreadSafeArray {

    /// Adds a new element at the end of the array.
    ///
    /// - Parameters:
    ///   - left: The collection to append to.
    ///   - right: The element to append to the array.
    static func += (left: inout ThreadSafeArray, right: Element) {
        left.append(right)
    }

    /// Adds new elements at the end of the array.
    ///
    /// - Parameters:
    ///   - left: The collection to append to.
    ///   - right: The elements to append to the array.
    static func += (left: inout ThreadSafeArray, right: [Element]) {
        left.append(right)
    }
}
