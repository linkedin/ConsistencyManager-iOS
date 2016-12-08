// © 2016 LinkedIn Corp. All rights reserved.
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at  http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.

import Foundation
import XCTest
import ConsistencyManager

/**
TODO: Add tests to this file which test the protocol and the procotol: class as T.
This currently doens't work (apple bugs)
*/

/**
This class is used for testing weak arrays.
*/
class TestWeakArrayClass {
    let value: Int
    init(value: Int) {
        self.value = value
    }
}

class TestWeakArrayClassTwo {
    let data: Int
    init(data: Int) {
        self.data = data
    }
}

class WeakArrayTests: ConsistencyManagerTestCase {

    // MARK: - Basic Functionality

    func testWeakArrayBasic() {
        var array: WeakArray<TestWeakArrayClass> = {
            var array = WeakArray<TestWeakArrayClass>()
            let test = TestWeakArrayClass(value: 0)
            array.append(test)
            XCTAssertNotNil(array[0])
            return array
            }()
        XCTAssertNil(array[0])
    }

    func testRepeatedValues() {
        let weakArray: WeakArray<TestWeakArrayClass> = {
            let testClass = TestWeakArrayClass(value: 1)
            let weakArray: WeakArray<TestWeakArrayClass> = [testClass, testClass]
            XCTAssertNotNil(weakArray[0])
            XCTAssertNotNil(weakArray[1])
            XCTAssertTrue(weakArray[1] === weakArray[0])

            return weakArray
            }()

        // Now we're out of scope, both values should be nil
        XCTAssertNil(weakArray[0])
        XCTAssertNil(weakArray[1])
    }

    // MARK: - Initializers

    func testCapacityCount() {
        for count in 0..<100 {
            let test = WeakArray<TestWeakArrayClass>(count: count)
            XCTAssertEqual(count, test.count)
        }
    }

    func testArrayLiteralEmpty() {
        let array: WeakArray<TestWeakArrayClass> = []
        XCTAssertEqual(array.count, 0)
    }

    func testArrayLiteralFull() {
        let array: WeakArray<TestWeakArrayClass> = {
            var strongArray = [TestWeakArrayClass(value: 0), TestWeakArrayClass(value: 1), TestWeakArrayClass(value: 2)]
            let array: WeakArray<TestWeakArrayClass> = [strongArray[0], strongArray[1], strongArray[2]]
            for i in 0..<3 {
                XCTAssertTrue(array[i] === strongArray[i])
            }
            return array
            }()

        // Everythings out of scope now, so let's check that its nil
        for element in array {
            XCTAssertNil(element)
        }
    }

    func testArrayLiteralNil() {
        let array: WeakArray<TestWeakArrayClass> = [nil, nil, nil]
        for element in array {
            XCTAssertNil(element)
        }
    }

    func testArrayLiteralPartial() {
        let array: WeakArray<TestWeakArrayClass> = {
            var strongArray = [TestWeakArrayClass(value: 0), TestWeakArrayClass(value: 1), TestWeakArrayClass(value: 2)]
            let array: WeakArray<TestWeakArrayClass> = [strongArray[0], nil, strongArray[1], nil, strongArray[2], nil]
            for i in 0..<6 {
                if i % 2 == 0 {
                    XCTAssertTrue(array[i] === strongArray[i / 2])
                } else {
                    XCTAssertNil(array[i])
                }
            }
            return array
            }()

        // Everythings out of scope now, so let's check that its nil
        for element in array {
            XCTAssertNil(element)
        }
    }

    // MARK: - Properties

    func testCount() {
        for count in 0..<100 {
            var array = WeakArray<TestWeakArrayClass>()
            for _ in 0..<count {
                array.append(TestWeakArrayClass(value: 0))
            }
            XCTAssertEqual(count, array.count)
        }
    }

    // MARK: - Public Methods

    // MARK: Prune

    func testPruneAllNil() {
        for count in 0..<100 {
            var weakArray: WeakArray<TestWeakArrayClass> = {
                var strongArray = [TestWeakArrayClass]()
                var weakArray = WeakArray<TestWeakArrayClass>()

                for _ in 0..<count {
                    let testObject = TestWeakArrayClass(value: 0)
                    strongArray.append(testObject)
                    weakArray.append(testObject)
                }

                // Nothing should be pruned because everything is still here
                XCTAssertEqual(weakArray.prune().count, count)
                XCTAssertEqual(weakArray.count, count)

                return weakArray
                }()

            // We haven't pruned yet, so count won't have changed
            XCTAssertEqual(weakArray.count, count)
            // Now prune should take everything out of the array
            XCTAssertEqual(weakArray.prune().count, 0)
            XCTAssertEqual(weakArray.count, 0)
        }
    }

    func testPruneSomeNil() {
        for count in 0..<100 {
            var outerStrongArray = [TestWeakArrayClass]()
            var weakArray: WeakArray<TestWeakArrayClass> = {
                var strongArray = [TestWeakArrayClass]()
                var weakArray = WeakArray<TestWeakArrayClass>()

                for i in 0..<count {
                    let testObject = TestWeakArrayClass(value: i)
                    strongArray.append(testObject)
                    weakArray.append(testObject)
                    if i % 2 == 1 {
                        // Let's keep this around until the end
                        // So here, we're keeping all the odd values
                        outerStrongArray.append(testObject)
                    }
                }

                // Nothing should be pruned because everything is still here
                XCTAssertEqual(weakArray.prune().count, count)
                XCTAssertEqual(weakArray.count, count)

                return weakArray
                }()

            // Now prune should take everything out of the array
            XCTAssertEqual(weakArray.prune().count, count / 2)
            XCTAssertEqual(weakArray.count, count / 2)

            for i in 0..<count / 2 {
                // The values in the array should be [ 1, 3, 5, 7 ... ]
                XCTAssertEqual(weakArray[i]!.value, i * 2 + 1)
            }
        }
    }

    // MARK: Map

    func testMapSameClass() {
        for count in 0..<100 {
            var strongArray = [TestWeakArrayClass]()
            var weakArray = WeakArray<TestWeakArrayClass>()

            for i in 0..<count {
                let testObject = TestWeakArrayClass(value: i)
                strongArray.append(testObject)
                weakArray.append(testObject)
            }

            let mappedWeakArray: WeakArray<TestWeakArrayClass> = weakArray.map { element in
                let newElement = TestWeakArrayClass(value: element!.value + 1)
                strongArray.append(newElement)
                return newElement
            }

            let sequence = mappedWeakArray.enumerated()
            for (index, element) in sequence {
                if let element = element {
                    XCTAssertEqual(index + 1, element.value)
                } else {
                    XCTFail()
                }
            }
        }
    }

    func testMapDifferentClass() {
        for count in 0..<100 {
            var strongArray = [TestWeakArrayClass]()
            var strongArrayTwo = [TestWeakArrayClassTwo]()

            var weakArray = WeakArray<TestWeakArrayClass>()

            for i in 0..<count {
                let testObject = TestWeakArrayClass(value: i)
                strongArray.append(testObject)
                weakArray.append(testObject)
            }

            let mappedWeakArray: WeakArray<TestWeakArrayClassTwo> = weakArray.map { element in
                let newElement = TestWeakArrayClassTwo(data: element!.value + 1)
                strongArrayTwo.append(newElement)
                return newElement
            }

            let sequence = mappedWeakArray.enumerated()
            for (index, element) in sequence {
                if let element = element {
                    XCTAssertEqual(index + 1, element.data)
                } else {
                    XCTFail()
                }
            }
        }
    }

    func testMapDoesntPrune() {
        for count in 0..<100 {
            var outerStrongArray = [TestWeakArrayClass]()
            let weakArray: WeakArray<TestWeakArrayClass> = {
                var strongArray = [TestWeakArrayClass]()
                var weakArray = WeakArray<TestWeakArrayClass>()

                for i in 0..<count {
                    let testObject = TestWeakArrayClass(value: i)
                    strongArray.append(testObject)
                    weakArray.append(testObject)
                    if i % 2 == 0 {
                        // Let's keep this around until the end
                        // So here, we're keeping all the odd values
                        outerStrongArray.append(testObject)
                    }
                }

                // Nothing should be pruned because everything is still here
                XCTAssertEqual(weakArray.prune().count, count)
                XCTAssertEqual(weakArray.count, count)

                return weakArray
            }()

            var mapCount = 0

            let mappedWeakArray: WeakArray<TestWeakArrayClass> = weakArray.map { element in
                mapCount += 1
                let newElement = element.flatMap { element in
                    TestWeakArrayClass(value: element.value + 1)
                }
                newElement.flatMap { element in
                    outerStrongArray.append(element)
                }
                return newElement
            }

            // Map shouldn't remove any elements
            XCTAssertEqual(mapCount, count)

            let sequence = mappedWeakArray.enumerated()
            for (index, element) in sequence {
                if let element = element {
                    XCTAssertEqual(index + 1, element.value)
                }
                // There should be some nil elements
            }
        }
    }

    // MARK: FlatMap

    func testFlatMapSameClass() {
        for count in 0..<100 {
            var strongArray = [TestWeakArrayClass]()
            var weakArray = WeakArray<TestWeakArrayClass>()

            for i in 0..<count {
                let testObject = TestWeakArrayClass(value: i)
                strongArray.append(testObject)
                weakArray.append(testObject)
            }

            let mappedWeakArray: WeakArray<TestWeakArrayClass> = weakArray.flatMap { element in
                if element!.value % 2 == 1 {
                    // remove these elements
                    return nil
                }
                let newElement = TestWeakArrayClass(value: element!.value + 1)
                strongArray.append(newElement)
                return newElement
            }

            let sequence = mappedWeakArray.enumerated()
            for (index, element) in sequence {
                if let element = element {
                    XCTAssertEqual((index * 2) + 1, element.value)
                } else {
                    XCTFail()
                }
            }
        }
    }

    func testFlatMapDifferentClass() {
        for count in 0..<100 {
            var strongArray = [TestWeakArrayClass]()
            var strongArrayTwo = [TestWeakArrayClassTwo]()

            var weakArray = WeakArray<TestWeakArrayClass>()

            for i in 0..<count {
                let testObject = TestWeakArrayClass(value: i)
                strongArray.append(testObject)
                weakArray.append(testObject)
            }

            let mappedWeakArray: WeakArray<TestWeakArrayClassTwo> = weakArray.flatMap { element in
                if element!.value % 2 == 1 {
                    // remove these elements
                    return nil
                }
                let newElement = TestWeakArrayClassTwo(data: element!.value + 1)
                strongArrayTwo.append(newElement)
                return newElement
            }

            let sequence = mappedWeakArray.enumerated()
            for (index, element) in sequence {
                if let element = element {
                    XCTAssertEqual((index * 2) + 1, element.data)
                } else {
                    XCTFail()
                }
            }
        }
    }

    func testFlatMapPrunes() {
        for count in 0..<100 {
            var outerStrongArray = [TestWeakArrayClass]()
            let weakArray: WeakArray<TestWeakArrayClass> = {
                var strongArray = [TestWeakArrayClass]()
                var weakArray = WeakArray<TestWeakArrayClass>()

                for i in 0..<count {
                    let testObject = TestWeakArrayClass(value: i)
                    strongArray.append(testObject)
                    weakArray.append(testObject)
                    if i % 2 == 0 {
                        // Let's keep this around until the end
                        // So here, we're keeping all the odd values
                        outerStrongArray.append(testObject)
                    }
                }

                // Nothing should be pruned because everything is still here
                XCTAssertEqual(weakArray.prune().count, count)
                XCTAssertEqual(weakArray.count, count)

                return weakArray
            }()

            var mapCount = 0

            let mappedWeakArray: WeakArray<TestWeakArrayClass> = weakArray.flatMap { element in
                mapCount += 1

                if let element = element, element.value % 4 == 2 {
                    // remove these elements
                    // After this, we should have 1/4 of the original elements in the array
                    return nil
                }
                let newElement = element.flatMap { element in
                    TestWeakArrayClass(value: element.value + 1)
                }
                newElement.flatMap { element in
                    outerStrongArray.append(element)
                }
                return newElement
            }

            // Flatmap should still call on every element, even though we've now removed 3/4 of them
            XCTAssertEqual(mapCount, count)
            XCTAssertEqual(mappedWeakArray.count, (count + 3) / 4)

            let sequence = mappedWeakArray.enumerated()
            for (index, element) in sequence {
                if let element = element {
                    XCTAssertEqual((index * 4) + 1, element.value)
                } else {
                    XCTFail()
                }
            }
        }
    }

    // MARK: - Filter

    func testFilter() {
        for count in 0..<100 {
            var strongArray = [TestWeakArrayClass]()
            var weakArray = WeakArray<TestWeakArrayClass>()

            for i in 0..<count {
                let testObject = TestWeakArrayClass(value: i)
                strongArray.append(testObject)
                weakArray.append(testObject)
            }

            let mappedWeakArray = weakArray.filter { element in
                return element!.value % 2 == 0
            }

            let sequence = mappedWeakArray.enumerated()
            for (index, element) in sequence {
                if let element = element {
                    XCTAssertEqual((index * 2), element.value)
                } else {
                    XCTFail()
                }
            }
        }
    }

    // MARK: - MutableCollectionType Tests

    func testGetterSetter() {
        for count in 0..<100 {
            var weakArray = WeakArray<TestWeakArrayClass>(count: count)
            for i in 0..<count {
                // Assert everything is nil after initializing
                XCTAssertNil(weakArray[i])
                let test = TestWeakArrayClass(value: i)
                weakArray[i] = test
                XCTAssertEqual(weakArray[i]!.value, i)
            }
            // Now everything is out of scope, so everything should be nil again
            for i in 0..<count {
                XCTAssertNil(weakArray[i])
            }
        }
    }
    
    /**
    This test ensures that the sequence methods work correctly.
    It verifies that when you create an array with X items, that you can iterate over these values.
    */
    func testSequenceType() {
        for count in 0..<100 {
            let weakArray: WeakArray<TestWeakArrayClass> = {
                var strongArray = [TestWeakArrayClass]()
                var weakArray = WeakArray<TestWeakArrayClass>()
                for i in 0..<count {
                    let testObject = TestWeakArrayClass(value: i)
                    strongArray.append(testObject)
                    weakArray.append(testObject)
                }
                var seenArray = Array<Bool>(repeating: false, count: count)
                
                // Now let's test the iterator phase 1
                for element in weakArray {
                    if let element = element {
                        seenArray[element.value] = true
                    } else {
                        XCTFail("It shouldn't ever be nil")
                    }
                }
                
                for seen in seenArray {
                    XCTAssertTrue(seen)
                }
                
                return weakArray
                }()
            
            // Now let's test the weak array iterating over nil values
            var iterations = 0
            for element in weakArray {
                XCTAssertNil(element)
                iterations += 1
            }
            // Should have iterated over every value
            XCTAssertEqual(iterations, count)
        }
    }
}
