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

class DeleteTests: ConsistencyManagerTestCase {

    func testDeleteWholeModel() {
        let model = TestRequiredModel(id: "0", data: 0)

        let consistencyManager = ConsistencyManager()
        let listener = TestListener(model: model)

        addListener(listener, toConsistencyManager: consistencyManager)

        deleteModel(model, consistencyManager: consistencyManager)

        XCTAssertTrue(listener.model == nil)
    }

    func testDeleteWholeModelProjection() {
        let model = TestModel(id: "0", data: 0, children: [], requiredModel: TestRequiredModel(id: "1", data: 0))

        let consistencyManager = ConsistencyManager()
        let listener = TestListener(model: model)

        addListener(listener, toConsistencyManager: consistencyManager)

        let modelToDelete = ProjectionTestModel(id: "0", data: nil, otherData: nil, children: [], requiredModel: TestRequiredModel(id: "1", data: 0))

        deleteModel(modelToDelete, consistencyManager: consistencyManager)

        XCTAssertTrue(listener.model == nil)
    }

    func testDeleteOptionalChild() {
        let requiredModel = TestRequiredModel(id: "100", data: 0)
        let child = TestModel(id: "1", data: nil, children: [], requiredModel: requiredModel)
        let model = TestModel(id: "0", data: nil, children: [child], requiredModel: requiredModel)

        let consistencyManager = ConsistencyManager()
        let listener = TestListener(model: model)

        addListener(listener, toConsistencyManager: consistencyManager)

        deleteModel(child, consistencyManager: consistencyManager)

        // The child model should have disappeared
        let expected = TestModel(id: "0", data: nil, children: [], requiredModel: requiredModel)
        if let model = listener.model as? TestModel {
            XCTAssertEqual(model, expected)
        } else {
            XCTFail()
        }
    }

    func testDeleteOptionalChildProjection() {
        let requiredModel = TestRequiredModel(id: "100", data: 0)
        let child = TestModel(id: "1", data: nil, children: [], requiredModel: requiredModel)
        let model = TestModel(id: "0", data: nil, children: [child], requiredModel: requiredModel)

        let consistencyManager = ConsistencyManager()
        let listener = TestListener(model: model)

        addListener(listener, toConsistencyManager: consistencyManager)

        let modelToDelete = ProjectionTestModel(id: "1", data: nil, otherData: nil, children: [], requiredModel: requiredModel)

        deleteModel(modelToDelete, consistencyManager: consistencyManager)

        // The child model should have disappeared
        let expected = TestModel(id: "0", data: nil, children: [], requiredModel: requiredModel)
        if let model = listener.model as? TestModel {
            XCTAssertEqual(model, expected)
        } else {
            XCTFail()
        }
    }

    func testDeleteRequiredModel() {
        let requiredModel = TestRequiredModel(id: "100", data: 0)
        let child = TestModel(id: "1", data: nil, children: [], requiredModel: requiredModel)
        let model = TestModel(id: "0", data: nil, children: [child], requiredModel: requiredModel)

        let consistencyManager = ConsistencyManager()
        let listener = TestListener(model: model)

        addListener(listener, toConsistencyManager: consistencyManager)

        deleteModel(requiredModel, consistencyManager: consistencyManager)
        
        // This should have caused a cascading delete
        XCTAssertNil(listener.model)
    }

    func testDeleteChildRequiredModel() {
        let requiredModel = TestRequiredModel(id: "100", data: 0)
        let child = TestModel(id: "1", data: nil, children: [], requiredModel: requiredModel)
        let model = TestModel(id: "0", data: nil, children: [child], requiredModel: TestRequiredModel(id: "2", data: 2))

        let consistencyManager = ConsistencyManager()
        let listener = TestListener(model: model)

        addListener(listener, toConsistencyManager: consistencyManager)

        deleteModel(requiredModel, consistencyManager: consistencyManager)

        // This should have caused a cascading delete
        // The child model should have disappeared
        let expected = TestModel(id: "0", data: nil, children: [], requiredModel: TestRequiredModel(id: "2", data: 2))
        if let model = listener.model as? TestModel {
            XCTAssertTrue(model == expected)
        } else {
            XCTFail()
        }
    }
}
