// © 2016 LinkedIn Corp. All rights reserved.
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at  http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.

import UIKit
import XCTest
import ConsistencyManager

/**
 These tests measure the most important performance characteristics of the library. They are in the sample app tests because you cannot run library tests on a device.

 All of the tests are run on the simulator and an iPhone 6 Plus.

 NOTES

 - Major performance improvement was not merging dictionaries when adding to the manager and not using inout. Instead, the dictionaries and arrays were boxed in a class.
 - Possible future improvement - use an NSSet for the listeners instead of arrays. This cannot be implemented in swift because the listeners aren't hashable (but they actually are because of inter-op). It would need to be a weak set though. Perhaps it could be used as an intermediate data structure (or just write a NSWeakSet).
 */
class PerformanceTests: ConsistencyManagerTestCase {

    /**
     This test tests an array of 500 models each with one child. One model will listen, and we'll see how long the update takes. The update will just post the exact same model back.

     Current Results

     Simulator (iPhone 5): 0.150
     iPhone 6+: 0.367
     */
    func testWideModelSingleListener() {
        let model = TestModelGenerator.testModelWithTotalChildren(1000, branchingFactor: 1000) { _ in return true }
        let listener = TestListener(model: model)
        let consistencyManager = ConsistencyManager()

        addListener(listener, toConsistencyManager: consistencyManager)

        // Now let's test this by giving the SAME model as an update. This takes a lot of work because everything is considered a change.
        measureBlock() {
            self.updateWithNewModel(model, consistencyManager: consistencyManager, timeout: 1000)
        }
    }

    /**
     This test tests an array of 500 models each with one child. One model will listen, and we'll see how long the update takes. The update will just post the exact same model back.

     Current Results

     Simulator (iPhone 5): 0.238
     iPhone 6+: 0.668
     */
    func testWideModelMultipleListeners() {
        let model = TestModelGenerator.testModelWithTotalChildren(300, branchingFactor: 300) { _ in return true }
        let consistencyManager = ConsistencyManager()

        let listeners: [TestListener] = {
            var listeners = [TestListener]()
            for _ in 0..<10 {
                listeners.append(TestListener(model: model))
            }
            return listeners
        }()

        _ = listeners.map {
            addListener($0, toConsistencyManager: consistencyManager)
        }

        // Now let's test this by giving the SAME model as an update. This takes a lot of work because everything is considered a change.
        measureBlock() {
            self.updateWithNewModel(model, consistencyManager: consistencyManager, timeout: 1000)
        }
    }

    /**
     This test tests a deep model of 500 models each with one child. One model will listen, and we'll see how long the update takes. The update will just post the exact same model back.

     Current Results

     Simulator (iPhone 5): 0.158
     iPhone 6+: 0.366
     */
    func testDeepModelSingleListener() {
        let model = TestModelGenerator.testModelWithTotalChildren(1000, branchingFactor: 2) { _ in return true }
        let listener = TestListener(model: model)
        let consistencyManager = ConsistencyManager()

        addListener(listener, toConsistencyManager: consistencyManager)

        // Now let's test this by giving the SAME model as an update. This takes a lot of work because everything is considered a change.
        measureBlock() {
            self.updateWithNewModel(model, consistencyManager: consistencyManager, timeout: 1000)
        }
    }

    /**
     This test takes a model with 1000 children and tests how long adding a listener takes.

     Current Results

     Simulator (iPhone 5): 0.022
     iPhone 6+: 0.063
     */
    func testListenerSpeedLargeModel() {
        let model = TestModelGenerator.testModelWithTotalChildren(1000, branchingFactor: 50) { _ in return true }
        let listener = TestListener(model: model)
        let consistencyManagers = Array<ConsistencyManager>(count: 20, repeatedValue: ConsistencyManager())

        var index = 0
        measure() {
            index += 1
            XCTAssert(index < consistencyManagers.count, "Looks like measure block is now taking more polls than before. Need to increase the count on the array.")
            self.addListener(listener, toConsistencyManager: consistencyManagers[index])
        }
    }
}
