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

class ShortCurcuitTests: ConsistencyManagerTestCase {

    func testSimpleShortCurcuit() {
        let testModel = TestModelGenerator.testModelWithTotalChildren(20, branchingFactor: 3) { id in
            // Let's test this with some ids missing
            return id % 3 == 0
        }

        let consistencyManager = ConsistencyManager()
        let listener = TestListener(model: testModel)

        addListener(listener, toConsistencyManager: consistencyManager)

        // Pick a random child
        let updateModel = testModel.children[1].children[2]
        XCTAssertNotNil(updateModel.id, "If this is nil, this test won't work. Make sure to pick a model with a real id")

        listener.updateClosure = { _ in
            // We shouldn't get called since the new model doesn't cause the model to change
            // It should have short curcuited
            XCTFail()
        }

        updateNewModel(updateModel, consistencyManager: consistencyManager)

        // Let's now create an update which should cause the consistency manager to update
        let secondUpdateModel = TestModel(id: updateModel.id, data: -42, children: updateModel.children, requiredModel: updateModel.requiredModel)

        var calledUpdateClosure = false
        listener.updateClosure = { model, updates in
            calledUpdateClosure = true
            if let model = model as? TestModel {
                // We should now have the updated data from the secondUpdateModel
                XCTAssertEqual(model.children[1].children[2].data, -42)
                // model.children[1] has a nil modelIdentifier, so only expect two ids updated here
                XCTAssertEqual(updates.changedModelIds.count, 2)
                XCTAssertTrue(updates.changedModelIds.contains(model.modelIdentifier!))
                XCTAssertTrue(updates.changedModelIds.contains(model.children[1].children[2].modelIdentifier!))
            } else {
                XCTFail()
            }
        }

        updateNewModel(secondUpdateModel, consistencyManager: consistencyManager)

        XCTAssertTrue(calledUpdateClosure)
    }
}
