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
@testable import ConsistencyManager

class ListenerTests: ConsistencyManagerTestCase {

    /**
    Test full models (everything has an ID
    */
    func testFullModels() {
        var now = Date()
        // Only want even number of models. See TestModelGenerator docs.
        for numberOfModels in stride(from: 2, through: 100, by: 4) {
            for branchingFactor in 1...10 {
                let testModel = TestModelGenerator.testModelWithTotalChildren(numberOfModels, branchingFactor: branchingFactor) { id in
                    // These are full models, so we want everything to have an id
                    return true
                }
                if -now.timeIntervalSinceNow > 10 {
                    print("first")
                    print(-now.timeIntervalSinceNow)
                    print("branching: \(branchingFactor) numberModels: \(numberOfModels)")
                }
                now = Date()

                runTestOnTestModel(testModel, maxId: numberOfModels - 1) { id in
                    return true
                }
                if -now.timeIntervalSinceNow > 10 {
                    print(-now.timeIntervalSinceNow)
                    print("branching: \(branchingFactor) numberModels: \(numberOfModels)")
                }
                now = Date()
            }
        }
    }

    /**
    Test partial models (some have ids some don't)
    */
    func testPartialModels() {
        // Only want even number of models. See TestModelGenerator docs.
        for numberOfModels in stride(from: 2, through: 100, by: 4) {
            for branchingFactor in 1...10 {
                let testModel = TestModelGenerator.testModelWithTotalChildren(numberOfModels, branchingFactor: branchingFactor) { id in
                    // Let's only put ids on a third of the models
                    return id % 3 == 0
                }

                runTestOnTestModel(testModel, maxId: numberOfModels - 1) { id in
                    return id % 3 == 0
                }
            }
        }
    }

    func testNoIdsOnModels() {
        // Only want even number of models. See TestModelGenerator docs.
        for numberOfModels in stride(from: 2, through: 100, by: 4) {
            for branchingFactor in 1...10 {
                let testModel = TestModelGenerator.testModelWithTotalChildren(numberOfModels, branchingFactor: branchingFactor) { id in
                    // Let's only put ids on a third of the models
                    return false
                }

                runTestOnTestModel(testModel, maxId: numberOfModels - 1) { id in
                    return false
                }
            }
        }
    }

    /**
    Partial test where the root has no ID
    */
    func testRootHasNoId() {
        // Only want even number of models. See TestModelGenerator docs.
        for numberOfModels in stride(from: 2, through: 100, by: 4) {
            for branchingFactor in 1...10 {
                let testModel = TestModelGenerator.testModelWithTotalChildren(numberOfModels, branchingFactor: branchingFactor) { id in
                    // Will return false for 0
                    return id % 3 == 1
                }

                runTestOnTestModel(testModel, maxId: numberOfModels - 1) { id in
                    return id % 3 == 1
                }
            }
        }
    }

    /*
    Makes sure a retain cycle doesn't exist.
    This partially depends on the implementation of ARC. So this may break in the future and will need to be fixed.
    */
    func testRetainCycle() {
        for numberOfModels in stride(from: 2, through: 100, by: 4) {
            for branchingFactor in 1...10 {
                let testModel = TestModelGenerator.testModelWithTotalChildren(numberOfModels, branchingFactor: branchingFactor) { id in
                    return id % 3 == 0
                }

                weak var listener: TestListener? = nil
                let consistencyManager = ConsistencyManager()

                autoreleasepool {
                    let strongListener = TestListener(model: testModel)
                    listener = strongListener

                    addListener(strongListener, toConsistencyManager: consistencyManager)
                    flushMainQueueOperations()
                }

                wait(for: listener == nil, timeout: 3, description: "Listener is deallocated")

                // Shouldn't be listening anymore
                for id in 0..<numberOfModels {
                    let listeners = consistencyManager.listeners["\(id)"]
                    if var listeners = listeners {
                        let prunedListeners = listeners.prune()
                        XCTAssertEqual(prunedListeners.count, 0)
                    }
                }
            }
        }
    }

    func testMultipleAdditions() {
        for numberOfModels in stride(from: 2, through: 40, by: 4) {
            for branchingFactor in 1...5 {
                let testModel = TestModelGenerator.testModelWithTotalChildren(numberOfModels, branchingFactor: branchingFactor) { id in
                    // Let's only put ids on a third of the models
                    return id % 3 == 0
                }

                let listener = TestListener(model: testModel)
                let consistencyManager = ConsistencyManager()

                // Let's add it as a listener multiple times. It should only be added once in the end though.
                for _ in 0..<10 {
                    addListener(listener, toConsistencyManager: consistencyManager)
                }

                for id in 0..<numberOfModels {
                    let shouldBePresent = id % 3 == 0

                    let listeners = consistencyManager.listeners["\(id)"]
                    if var listeners = listeners {
                        let prunedListeners = listeners.prune()

                        if shouldBePresent {
                            // Note here: We are making sure the number of listeners is exactly 1. No more.
                            XCTAssertEqual(prunedListeners.count, 1)
                            XCTAssertTrue(prunedListeners[0] === listener)
                        } else {
                            XCTAssertEqual(prunedListeners.count, 0)
                        }
                    } else {
                        if shouldBePresent {
                            XCTFail("Should have a listener array for this id")
                        }
                        // else it's good that this wasn't here
                    }
                }
            }
        }
    }

    func testMultipleListenersToSameModel() {
        // Only want even number of models. See TestModelGenerator docs.
        for numberOfModels in stride(from: 2, through: 100, by: 4) {
            for branchingFactor in 1...10 {
                let testModel = TestModelGenerator.testModelWithTotalChildren(numberOfModels, branchingFactor: branchingFactor) { id in
                    // Will return false for 0
                    return id % 3 == 1
                }

                let listener1 = TestListener(model: testModel)
                let listener2 = TestListener(model: testModel)

                let consistencyManager = ConsistencyManager()

                addListener(listener1, toConsistencyManager: consistencyManager)
                addListener(listener2, toConsistencyManager: consistencyManager)

                for id in 0..<numberOfModels {
                    let shouldBePresent = (id % 3 == 1)

                    let listeners = consistencyManager.listeners["\(id)"]
                    if var listeners = listeners {
                        let prunedListeners = listeners.prune()

                        if shouldBePresent {
                            XCTAssertEqual(prunedListeners.count, 2)
                            // Currently assuming the order will be maintained
                            // This assumption may break in the future, but unlikely
                            XCTAssertTrue(prunedListeners[0] === listener1)
                            XCTAssertTrue(prunedListeners[1] === listener2)
                        } else {
                            XCTAssertEqual(prunedListeners.count, 0)
                        }
                    } else {
                        if shouldBePresent {
                            XCTFail("Should have a listener array for this id")
                        }
                        // else it's good that this wasn't here
                    }
                }
            }
        }
    }

    func testMultipleListenersToDifferentModels() {
        // Only want even number of models. See TestModelGenerator docs.
        for numberOfModels in stride(from: 2, through: 40, by: 4) {
            for branchingFactor in 1...10 {
                let testModel1 = TestModelGenerator.testModelWithTotalChildren(numberOfModels, branchingFactor: branchingFactor) { id in
                    // Will return false for 0
                    return id % 3 == 1
                }

                let testModel2 = TestModelGenerator.testModelWithTotalChildren(numberOfModels, branchingFactor: branchingFactor, startingId: numberOfModels) { id in
                    // Will return false for 0
                    return id % 3 == 1
                }

                let listener1 = TestListener(model: testModel1)
                let listener2 = TestListener(model: testModel2)

                let consistencyManager = ConsistencyManager()

                addListener(listener1, toConsistencyManager: consistencyManager)
                addListener(listener2, toConsistencyManager: consistencyManager)

                for id in 0..<numberOfModels*2 {
                    let shouldBePresent = (id % 3 == 1)

                    let listeners = consistencyManager.listeners["\(id)"]
                    if var listeners = listeners {
                        let prunedListeners = listeners.prune()
                        
                        if shouldBePresent {
                            XCTAssertEqual(prunedListeners.count, 1)
                            if id < numberOfModels {
                                // Only listener1 should be listening here
                                XCTAssertTrue(prunedListeners[0] === listener1)
                            } else {
                                // Only listener2 should be listening here
                                XCTAssertTrue(prunedListeners[0] === listener2)
                            }
                        } else {
                            XCTAssertEqual(prunedListeners.count, 0)
                        }
                    } else {
                        if shouldBePresent {
                            XCTFail("Should have a listener array for this id")
                        }
                        // else it's good that this wasn't here
                    }
                }
            }
        }
    }
    
    /**
    Helper method.
    This method runs a test model throught he consistency manager and verifies that certain ids are being listened too.
    */
    func runTestOnTestModel(_ testModel: TestModel, maxId: Int, idShouldBePresent idFunction: (Int) -> Bool) {
        let listener = TestListener(model: testModel)
        let consistencyManager = ConsistencyManager()

        let now = Date()
        addListener(listener, toConsistencyManager: consistencyManager)
        if -now.timeIntervalSinceNow > 10 {
            print("add listener")
        }
        
        for id in 0...max(maxId, 0) {
            let shouldBePresent = idFunction(id)
            
            let listeners = consistencyManager.listeners["\(id)"]
            if var listeners = listeners {
                let prunedListeners = listeners.prune()
                
                if shouldBePresent {
                    XCTAssertEqual(prunedListeners.count, 1)
                    XCTAssertTrue(prunedListeners[0] === listener)
                } else {
                    XCTAssertEqual(prunedListeners.count, 0)
                }
            } else {
                if shouldBePresent {
                    XCTFail("Should have a listener array for this id")
                }
                // else it's good that this wasn't here
            }
        }
    }
}
