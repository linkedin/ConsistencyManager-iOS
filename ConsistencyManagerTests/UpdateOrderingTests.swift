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

class UpdateOrderingTests: ConsistencyManagerTestCase {

    func testConsistencyManagerUpdateOrder() {
        for testProjections in [true, false] {
            for numberOfModels in 30.stride(through: 50, by: 4) {
                for branchingFactor in 1...10 {
                    let testModel = TestModelGenerator.consistencyManagerModelWithTotalChildren(numberOfModels, branchingFactor: branchingFactor, projectionModel: testProjections) { id in
                        // Let's test this with some ids missing
                        return id % 3 == 0
                    }
                    // Just make another model which has 2 extra models (arbritrary big model which is different)
                    let newLargeModel = TestModelGenerator.testModelWithTotalChildren(numberOfModels+2, branchingFactor: branchingFactor) { id in
                        // Let's test this with some ids missing
                        return id % 3 == 0
                    }
                    let newModel = TestModel(id: "0", data: 0, children: [], requiredModel: TestRequiredModel(id: "-1", data: -1))

                    let consistencyManager = ConsistencyManager()
                    let listener = TestListener(model: testModel)

                    addListener(listener, toConsistencyManager: consistencyManager)

                    var numberTimesCallbackCalled = 0

                    // This will verify that the updates are made in the correct order.
                    // Even though the first update will be much longer, it should complete before the other.
                    listener.updateClosure = { model, updates in
                        if let model = self.testModelFromListenerModel(model) {
                            if numberTimesCallbackCalled == 0 {
                                numberTimesCallbackCalled += 1
                                // On first update, we should have the new large model
                                XCTAssertEqual(model, newLargeModel)
                            } else if numberTimesCallbackCalled == 1 {
                                numberTimesCallbackCalled += 1
                                // Second time, it should have changed to our new smaller model
                                XCTAssertEqual(model, newModel)
                            } else {
                                XCTFail()
                            }
                        } else {
                            XCTFail()
                        }
                    }

                    // First, let's do a long operation, which should complete first
                    // For this operation, we'll pass in the large model
                    consistencyManager.updateWithNewModel(newLargeModel)
                    consistencyManager.updateWithNewModel(newModel)

                    // NOTE: Here we SHOULD NOT use the SyncronousHelperFunctions class because that will ensure the ordering in the tests

                    // First we need to wait for the consistency manager to finish on its queue
                    let expectation = expectationWithDescription("Wait for consistency manager to finish it's task and async to the main queue")

                    let operation = NSBlockOperation() {
                        expectation.fulfill()
                    }
                    consistencyManager.queue.addOperation(operation)

                    waitForExpectationsWithTimeout(10) { error in
                        XCTAssertNil(error)
                    }

                    // Now, we need to wait for the main queue to do the actual updates
                    let mainQueueExpectation = expectationWithDescription("Wait for main queue to finish so the updates have happened")

                    dispatch_async(dispatch_get_main_queue()) {
                        mainQueueExpectation.fulfill()
                    }
                    
                    waitForExpectationsWithTimeout(10) { error in
                        XCTAssertNil(error)
                    }
                    
                    // Finally, let's verify that block actually got called
                    XCTAssertEqual(2, numberTimesCallbackCalled)
                }
            }
        }
    }
}
