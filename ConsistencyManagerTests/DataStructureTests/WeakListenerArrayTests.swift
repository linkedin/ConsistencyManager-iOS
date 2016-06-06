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


class WeakListenerArrayTests: ConsistencyManagerTestCase {

    // MARK: Basic Functionality

    func testWeakArrayBasic() {
        var array: WeakListenerArray = {
            var array = WeakListenerArray()
            let test = TestWeakArrayClass(value: 0)
            array.append(test)
            XCTAssertNotNil(array[0])
            return array
        }()
        XCTAssertNil(array[0])
    }

    func testRepeatedValues() {
        let weakArray: WeakListenerArray = {
            let testClass = TestWeakArrayClass(value: 1)
            let weakArray: WeakListenerArray = [testClass, testClass]
            XCTAssertNotNil(weakArray[0])
            XCTAssertNotNil(weakArray[1])
            XCTAssertTrue(weakArray[1] === weakArray[0])

            return weakArray
        }()

        // Now we're out of scope, both values should be nil
        XCTAssertNil(weakArray[0])
        XCTAssertNil(weakArray[1])
    }

    // MARK: Initializers

    func testCapacityCount() {
        for count in 0..<100 {
            let test = WeakListenerArray(count: count)
            XCTAssertEqual(count, test.count)
        }
    }

    func testArrayLiteralEmpty() {
        let array: WeakListenerArray = []
        XCTAssertEqual(array.count, 0)
    }

    func testArrayLiteralFull() {
        let array: WeakListenerArray = {
            var strongArray = [TestWeakArrayClass(value: 0), TestWeakArrayClass(value: 1), TestWeakArrayClass(value: 2)]
            let array: WeakListenerArray = [strongArray[0], strongArray[1], strongArray[2]]
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
        let array: WeakListenerArray = [nil, nil, nil]
        for element in array {
            XCTAssertNil(element)
        }
    }

    func testArrayLiteralPartial() {
        let array: WeakListenerArray = {
            var strongArray = [TestWeakArrayClass(value: 0), TestWeakArrayClass(value: 1), TestWeakArrayClass(value: 2)]
            let array: WeakListenerArray = [strongArray[0], nil, strongArray[1], nil, strongArray[2], nil]
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

    // MARK: Properties

    func testCount() {
        for count in 0..<100 {
            var array = WeakListenerArray()
            for _ in 0..<count {
                array.append(TestWeakArrayClass(value: 0))
            }
            XCTAssertEqual(count, array.count)
        }
    }

    // MARK: Public Methods

    func testPruneAllNil() {
        for count in 0..<100 {
            var weakArray: WeakListenerArray = {
                var strongArray = [TestWeakArrayClass]()
                var weakArray = WeakListenerArray()

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
            var weakArray: WeakListenerArray = {
                var strongArray = [TestWeakArrayClass]()
                var weakArray = WeakListenerArray()

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
                XCTAssertEqual((weakArray[i] as! TestWeakArrayClass).value, i * 2 + 1)
            }
        }
    }

    func testMapSameClass() {
        for count in 0..<100 {
            var strongArray = [TestWeakArrayClass]()
            var weakArray = WeakListenerArray()

            for i in 0..<count {
                let testObject = TestWeakArrayClass(value: i)
                strongArray.append(testObject)
                weakArray.append(testObject)
            }

            let mappedWeakArray: WeakListenerArray = weakArray.map { element in
                let newElement = TestWeakArrayClass(value: (element as! TestWeakArrayClass).value + 1)
                strongArray.append(newElement)
                return newElement
            }

            let sequence = mappedWeakArray.enumerate()
            for (index, element) in sequence {
                if let element = element {
                    XCTAssertEqual(index + 1, (element as! TestWeakArrayClass).value)
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

            var weakArray = WeakListenerArray()

            for i in 0..<count {
                let testObject = TestWeakArrayClass(value: i)
                strongArray.append(testObject)
                weakArray.append(testObject)
            }

            let mappedWeakArray: WeakListenerArray = weakArray.map { element in
                let newElement = TestWeakArrayClassTwo(data: (element as! TestWeakArrayClass).value + 1)
                strongArrayTwo.append(newElement)
                return newElement
            }

            let sequence = mappedWeakArray.enumerate()
            for (index, element) in sequence {
                if let element = element {
                    XCTAssertEqual(index + 1, (element as! TestWeakArrayClassTwo).data)
                } else {
                    XCTFail()
                }
            }
        }
    }

    // MARK: MutableCollectionType Tests

    func testGetterSetter() {
        for count in 0..<100 {
            var weakArray = WeakListenerArray(count: count)
            for i in 0..<count {
                // Assert everything is nil after initializing
                XCTAssertNil(weakArray[i])
                let test = TestWeakArrayClass(value: i)
                weakArray[i] = test
                XCTAssertEqual((weakArray[i] as! TestWeakArrayClass).value, i)
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
            let weakArray: WeakListenerArray = {
                var strongArray = [TestWeakArrayClass]()
                var weakArray = WeakListenerArray()
                for i in 0..<count {
                    let testObject = TestWeakArrayClass(value: i)
                    strongArray.append(testObject)
                    weakArray.append(testObject)
                }
                var seenArray = Array<Bool>(count: count, repeatedValue: false)

                // Now let's test the iterator phase 1
                for element in weakArray {
                    if let element = element {
                        seenArray[(element as! TestWeakArrayClass).value] = true
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

    /**
     This class is used for testing weak arrays.
     */
    class TestWeakArrayClass: ConsistencyManagerListener {
        let value: Int
        init(value: Int) {
            self.value = value
        }

        func currentModel() -> ConsistencyManagerModel? {
            return nil
        }

        func modelUpdated(model: ConsistencyManagerModel?, updates: ModelUpdates, context: Any?) {

        }
    }

    class TestWeakArrayClassTwo: ConsistencyManagerListener {
        let data: Int
        init(data: Int) {
            self.data = data
        }

        func currentModel() -> ConsistencyManagerModel? {
            return nil
        }

        func modelUpdated(model: ConsistencyManagerModel?, updates: ModelUpdates, context: Any?) {

        }
    }
}
