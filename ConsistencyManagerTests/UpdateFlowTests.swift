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
Here, I'm putting these in a new file to avoid the other file getting too big. These tests make sure that when a model is updated multiple times, the right things happen.
There are more individually tested rather than generically (property testing) than the other update tests.
*/
class UpdateFlowTests: ConsistencyManagerTestCase {

    /**
    If we make a change which adds a new child to a model, then we make another update that edits that child, then the child changes should be reflected.
    This is a special case because it ensures that the manager relistens to new models.
    */
    func testAddingNewSubmodel() {
        let requiredModel = TestRequiredModel(id: "100", data: 100)
        let subtree1 = TestModel(id: "1", data: 1, children: [], requiredModel: requiredModel)
        let testModel = TestModel(id: "0", data: 0, children: [subtree1], requiredModel: requiredModel)

        // Setup the manager and listener
        let consistencyManager = ConsistencyManager()
        let listener = TestListener(model: testModel)

        addListener(listener, toConsistencyManager: consistencyManager)

        // Now, let's create a model which has very simmilar data, but has an extra child added
        let extraChild = TestModel(id: "2", data: 2, children: [], requiredModel: requiredModel)
        let updateSubtree1 = TestModel(id: "1", data: 1, children: [extraChild], requiredModel: requiredModel)
        let updateTestModel = TestModel(id: "5", data: 0, children: [updateSubtree1], requiredModel: requiredModel)

        updateNewModel(updateTestModel, consistencyManager: consistencyManager)

        // New model should have the extra child added
        let expectedModel = TestModel(id: "0", data: 0, children: [updateSubtree1], requiredModel: requiredModel)
        if let model = listener.model as? TestModel {
            XCTAssertEqual(model, expectedModel)
        } else {
            XCTFail()
        }

        // NOW, for the real testing
        // Let's update this added child to be something different. The original model SHOULD update with these changes.
        // Note: I changed the data, and added a new child
        // Note: This new model must have NO ids in common with the previous model (except 2)
        let newRequiredModel = TestRequiredModel(id: "101", data: 101)
        let additionalChild = TestModel(id: "200", data: 200, children: [], requiredModel: newRequiredModel)
        let newChild = TestModel(id: "2", data: -2, children: [additionalChild], requiredModel: newRequiredModel)

        updateNewModel(newChild, consistencyManager: consistencyManager)

        let newUpdatedSubtree = TestModel(id: "1", data: 1, children: [newChild], requiredModel: requiredModel)
        let nextExpectedModel = TestModel(id: "0", data: 0, children: [newUpdatedSubtree], requiredModel: requiredModel)

        if let model = listener.model as? TestModel {
            XCTAssertEqual(model, nextExpectedModel)
        } else {
            XCTFail()
        }
    }

    /**
    This is the opposite test of above. In this test, we remove a child model, then do an update to that child model. This should mean that the callback on the listener SHOULD NOT be called.
    */
    func testRemovingSubmodel() {
        let requiredModel = TestRequiredModel(id: "100", data: 100)
        let child = TestModel(id: "2", data: 2, children: [], requiredModel: requiredModel)
        let subtree1 = TestModel(id: "1", data: 1, children: [child], requiredModel: requiredModel)
        let testModel = TestModel(id: "0", data: 0, children: [subtree1], requiredModel: requiredModel)

        // Setup the manager and listener
        let consistencyManager = ConsistencyManager()
        let listener = TestListener(model: testModel)

        addListener(listener, toConsistencyManager: consistencyManager)

        // Now, let's create a model where we remove the child from id = 1
        let newChild = TestModel(id: "3", data: 2, children: [], requiredModel: requiredModel)
        let updateSubtree1 = TestModel(id: "1", data: 1, children: [newChild], requiredModel: requiredModel)
        let updateTestModel = TestModel(id: "5", data: 0, children: [updateSubtree1], requiredModel: requiredModel)

        updateNewModel(updateTestModel, consistencyManager: consistencyManager)

        // New model should have the child updated
        let expectedModel = TestModel(id: "0", data: 0, children: [updateSubtree1], requiredModel: requiredModel)
        if let model = listener.model as? TestModel {
            XCTAssertEqual(model, expectedModel)
        } else {
            XCTFail()
        }

        // NOW, for the real testing
        // Let's do an update on the old child which isn't part of the tree.
        // The callback on the listener SHOULD NOT be called (because it has no ids in common with the current tree
        let newRequiredModel = TestRequiredModel(id: "101", data: 101)
        let additionalChild = TestModel(id: "200", data: 200, children: [], requiredModel: newRequiredModel)
        let originalChildUpdated = TestModel(id: "2", data: -2, children: [additionalChild], requiredModel: newRequiredModel)
        
        listener.updateClosure = { _ in
            XCTFail()
        }
        
        updateNewModel(originalChildUpdated, consistencyManager: consistencyManager)
        
        // Double check to make sure everything is as before
        if let model = listener.model as? TestModel {
            XCTAssertEqual(model, expectedModel)
        } else {
            XCTFail()
        }
    }
}
