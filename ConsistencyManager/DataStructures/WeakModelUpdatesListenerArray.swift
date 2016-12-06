// © 2016 LinkedIn Corp. All rights reserved.
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at  http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.

import Foundation


/**
 This is a temporary workaround to an Apple bug. We can't specify a WeakArray<Protocol>, so I have to copy-paste it for a specific type.

 https://bugs.swift.org/browse/SR-1176
 */
public struct WeakModelUpdatesListenerArray: ExpressibleByArrayLiteral {

    // MARK: Internal

    /// The internal data is an array of closures which return weak T's
    fileprivate var data: [() -> ConsistencyManagerUpdatesListener?]

    // MARK: Initializers

    /**
     Creates an empty array
     */
    public init() {
        data = []
    }

    /**
     Creates an array with a certain capacity. All elements in the array will be nil.
     */
    public init(count: Int) {
        data = Array<() -> ConsistencyManagerUpdatesListener?>(repeating: {
            return nil
        }, count: count)
    }

    /**
     Array literal initializer. Allows you to initialize a WeakArray with array notation.
     */
    public init(arrayLiteral elements: ConsistencyManagerUpdatesListener?...) {
        data = []
        for element in elements {
            data.append(weakClosureWithValue(element))
        }
    }

    /**
     Private initializer which allows init with data.
     */
    private init(data: [() -> ConsistencyManagerUpdatesListener?]) {
        self.data = data
    }

    // MARK: Public Properties

    /// How many elements the Array stores
    public var count: Int {
        return data.count
    }

    // MARK: Public Methods

    /**
     Append an element to the array.
     */
    public mutating func append(_ element: ConsistencyManagerUpdatesListener?) {
        data.append(weakClosureWithValue(element))
    }

    /**
     This method iterates through the array and removes any element which is nil.
     It also returns an array of nonoptional values for convenience.

     This method runs in O(n), so you should only call this method every time you need it. You should only call it once.
     i.e. Don't do this:
     for _ in array.prune()
     */
    public mutating func prune() -> [ConsistencyManagerUpdatesListener] {
        var nonOptionalElements = [ConsistencyManagerUpdatesListener]()
        data = data.filter { closure in
            let value = closure()
            if let value = value {
                nonOptionalElements.append(value)
                return true
            } else {
                return false
            }
        }
        return nonOptionalElements
    }

    public func map(_ function: (ConsistencyManagerUpdatesListener?) -> ConsistencyManagerUpdatesListener?) -> WeakModelUpdatesListenerArray {
        var newArray = WeakModelUpdatesListenerArray()
        // TODO: Fix this once apple fixes their bug
        // This currently crashes with EXC_BAD_ACCESS
        //    for value in self {
        //      let newValue = function(value)
        //      newArray.append(newValue)
        //    }
        for closure in data {
            let newValue = function(closure())
            newArray.append(newValue)
        }
        return newArray
    }

    /**
     Iterates over the collection with an include element closure.
     It will remove any elements that return false.
     */
    func filter(_ includeElement: (ConsistencyManagerUpdatesListener?) -> Bool) -> WeakModelUpdatesListenerArray {
        let newData = data.filter { closure in
            return includeElement(closure())
        }
        return WeakModelUpdatesListenerArray(data: newData)
    }

    // MARK: Private Methods

    fileprivate func weakClosureWithValue(_ object: ConsistencyManagerUpdatesListener?) -> () -> ConsistencyManagerUpdatesListener? {
        return { [weak object] in
            return object
        }
    }
}

// MARK: MutableCollectionType Implementation

extension WeakModelUpdatesListenerArray: MutableCollection {

    // Required by SequenceType
    public func makeIterator() -> IndexingIterator<WeakModelUpdatesListenerArray> {
        // Rather than implement our own generator, let's take advantage of the generator provided by IndexingGenerator
        return IndexingIterator<WeakModelUpdatesListenerArray>(_elements: self)
    }

    // Required by _CollectionType
    public func index(after i: Int) -> Int {
        return i + 1
    }

    // Required by _CollectionType
    public var endIndex: Int {
        return self.count
    }

    // Required by _CollectionType
    public var startIndex: Int {
        return 0
    }

    /**
     Getter and setter array
     */
    public subscript(index: Int) -> ConsistencyManagerUpdatesListener? {
        get {
            let closure = data[index]
            return closure()
        }
        set {
            data[index] = weakClosureWithValue(newValue)
        }
    }
}
