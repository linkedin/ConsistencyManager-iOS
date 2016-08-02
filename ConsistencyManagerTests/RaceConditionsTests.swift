// © 2016 LinkedIn Corp. All rights reserved.
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at  http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.

import XCTest
import ConsistencyManager

class RaceConditionsTests: ConsistencyManagerTestCase {

    /**
     1) An update occurs which affects a listener
     2) The listener is asked for it's current model
     3) The consistency manager does some work
     4) The listener changes its own model for some other reason
     5) The consistency manager reports the change
     */
    func testCurrentModelRaceCondition() {
        for testProjections in [true, false] {
            let initialModel = TestModelGenerator.consistencyManagerModelWithTotalChildren(2, branchingFactor: 0, projectionModel: testProjections) { id in
                return id == 0
            }

            let consistencyManager = ConsistencyManager()
            let listener = TestListener(model: initialModel)

            addListener(listener, toConsistencyManager: consistencyManager)

            // Have a model to change to
            let updateModel = TestModel(id: "0", data: 1, children: [], requiredModel: TestRequiredModel(id: nil, data: -1))
            let newModel = TestModel(id: "2", data: 2, children: [], requiredModel: TestRequiredModel(id: nil, data: -1))

            listener.updateClosure = { context in
                XCTFail()
            }

            var updates = 0
            listener.currentModelRequested = {
                // After we have requested the current model, we're going to change it to another model (but only the first time). This simulates the race condition.
                // The reason this is only necessary the first time is that changing the model in this method is an antipattern. This just simulates the bug. The second time it's called, it's called on the same thread as the update happenes so there can be no race condition there.
                if updates == 0 {
                    listener.model = newModel
                    updates += 1
                }
            }

            updateWithNewModel(updateModel, consistencyManager: consistencyManager, context: 4)
            
            // Should have the new model here
            XCTAssertEqual(testModelFromListenerModel(listener.model)?.data, 2)
            XCTAssertEqual(updates, 1)
        }
    }

    /**
    One of the guarentees made by the consistency manager is that when an update happens:
    - All of the current models are requested in the same block
    - All of the updateModel calls occur in the same block
    This ensures that listeners will always get updated at the same time with the same data.
    This test verifies this.
    */
    func testSameMainThreadBlock() {
        let initialModel = TestModel(id: "0", data: 0, children: [], requiredModel: TestRequiredModel(id: "1", data: 0))

        let consistencyManager = ConsistencyManager()
        let listener1 = TestListener(model: initialModel)
        let listener2 = TestListener(model: TestRequiredModel(id: "1", data: 0))

        addListener(listener1, toConsistencyManager: consistencyManager)
        addListener(listener2, toConsistencyManager: consistencyManager)

        let updateModel = TestRequiredModel(id: "1", data: 1)

        var numberOfCurrentModelRequests = 0
        // This actually gets called 4 times
        // It gets called twice in a row first, then two more times again. These should each be grouped on their own thread.
        let modelRequested = {
            numberOfCurrentModelRequests += 1

            if numberOfCurrentModelRequests > 2 {
                dispatch_async(dispatch_get_main_queue()) {
                    XCTAssertEqual(numberOfCurrentModelRequests, 4)
                }
            } else {
                dispatch_async(dispatch_get_main_queue()) {
                    XCTAssertEqual(numberOfCurrentModelRequests, 2)
                }
            }
        }
        listener1.currentModelRequested = modelRequested
        listener2.currentModelRequested = modelRequested

        var updates = 0
        let modelUpdated: (ConsistencyManagerModel?, ModelUpdates) -> Void = { _, _ in
            updates += 1
            
            // Let's dispatch and get the next main block
            // When we do this, we should get both updated
            dispatch_async(dispatch_get_main_queue()) {
                XCTAssertEqual(updates, 2)
            }
        }
        listener1.updateClosure = modelUpdated
        listener2.updateClosure = modelUpdated

        updateWithNewModel(updateModel, consistencyManager: consistencyManager, context: nil)

        // Should have the new model here
        XCTAssertEqual((listener1.model as! TestModel).requiredModel.data, 1)
        XCTAssertEqual((listener2.model as! TestRequiredModel).data, 1)
    }
}
