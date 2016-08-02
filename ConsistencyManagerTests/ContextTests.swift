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

class ContextTests: ConsistencyManagerTestCase {

    func testContextPassedThrough() {
        for testProjections in [true, false] {
            let testModel = TestModelGenerator.consistencyManagerModelWithTotalChildren(20, branchingFactor: 3, projectionModel: testProjections) { id in
                return true
            }

            let consistencyManager = ConsistencyManager()
            let listener = TestListener(model: testModel)

            addListener(listener, toConsistencyManager: consistencyManager)

            // Pick a random child
            let updateModel = TestModel(id: "2", data: -1, children: [], requiredModel: TestRequiredModel(id: nil, data: -1))

            var contextClosureCalled = false
            listener.contextClosure = { context in
                contextClosureCalled = true
                XCTAssertEqual(context as? Int, 4)
            }

            updateWithNewModel(updateModel, consistencyManager: consistencyManager, context: 4)
            
            XCTAssertTrue(contextClosureCalled)
        }
    }
}
