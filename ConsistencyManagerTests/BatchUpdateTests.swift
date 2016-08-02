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

class BatchUpdateTests: ConsistencyManagerTestCase {

    func testSingleUpdate() {
        for testProjections in [true, false] {
            let testModel = TestModelGenerator.consistencyManagerModelWithTotalChildren(10, branchingFactor: 3, projectionModel: testProjections) { id in
                return true
            }

            let consistencyManager = ConsistencyManager()
            let listener = TestListener(model: testModel)

            addListener(listener, toConsistencyManager: consistencyManager)

            var numberOfUpdates = 0
            listener.updateClosure = { _ in
                numberOfUpdates += 1
            }

            let updateModel1 = TestModel(id: "2", data: -2, children: [], requiredModel: TestRequiredModel(id: "21", data: -1))
            let updateModel2 = TestModel(id: "4", data: -4, children: [], requiredModel: TestRequiredModel(id: "21", data: -1))
            let batchModel = BatchUpdateModel(models: [updateModel1, updateModel2])
            updateWithNewModel(batchModel, consistencyManager: consistencyManager)

            // Both models should have been updated, but we should only have gotten one update
            if let testModel = listener.model as? TestModel {
                XCTAssertEqual(testModel.children[0].data, -2)
                XCTAssertEqual(testModel.children[1].data, -4)
                XCTAssertEqual(numberOfUpdates, 1)
            } else if let testModel = listener.model as? ProjectionTestModel {
                XCTAssertEqual(testModel.children[0].data, -2)
                XCTAssertEqual(testModel.children[1].data, -4)
                XCTAssertEqual(numberOfUpdates, 1)
                // Other data shouldn't be edited and should be equal to the id of the model
                XCTAssertEqual(testModel.children[0].otherData, 2)
            } else {
                XCTFail()
            }
        }
    }
}
