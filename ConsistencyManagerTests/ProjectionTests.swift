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

class ProjectionTests: ConsistencyManagerTestCase {

    /**
     This tests a simple tree with one child.
     The child is a .both projection, but the update model is a .otherData projection.
     Only the otherData field should be updated on the original model.
     */
    func testUpdatingOneModelUpdatesTheOther() {
        let child = ProjectionTreeModel(type: .both, id: 1, data: 2, otherData: 2, child: nil, otherChild: nil)
        let testModel = ProjectionTreeModel(type: .both, id: 0, data: 1, otherData: 1, child: child, otherChild: nil)

        let consistencyManager = ConsistencyManager()
        let listener = TestListener(model: testModel)

        addListener(listener, toConsistencyManager: consistencyManager)

        listener.contextClosure = { context in
            XCTAssertEqual(context as? String, "context")
        }

        listener.updateClosure = { _, updates in
            XCTAssertEqual(updates.changedModelIds.count, 2)
            XCTAssertEqual(updates.deletedModelIds.count, 0)
            XCTAssertTrue(updates.changedModelIds.contains("1"))
            XCTAssertTrue(updates.changedModelIds.contains("0"))
        }

        let updateModel = ProjectionTreeModel(type: .otherData, id: 1, data: nil, otherData: 4, child: nil, otherChild: nil)
        // We expect otherData to update but data to be left alone
        let expectedModel = ProjectionTreeModel(type: .both, id: 1, data: 2, otherData: 4, child: nil, otherChild: nil)

        updateWithNewModel(updateModel, consistencyManager: consistencyManager, context: "context")

        // Should have updated the model of the listener
        if let testModel = listener.model as? ProjectionTreeModel {
            XCTAssertEqual(testModel.child, expectedModel)
        } else {
            XCTFail()
        }
    }

    /**
     This tests a tree with two children with the same id.
     But, both children are different projections (one is .data, the other is .otherData).
     We update this with a .both projection. We expect both the data field and the otherData field of this model to update.
     */
    func testUpdatingModelWithTwoSubmodels() {
        let firstChild = ProjectionTreeModel(type: .data, id: 1, data: 2, otherData: nil, child: nil, otherChild: nil)
        let otherChild = ProjectionTreeModel(type: .otherData, id: 1, data: nil, otherData: 4, child: nil, otherChild: nil)
        let testModel = ProjectionTreeModel(type: .both, id: 0, data: 1, otherData: 1, child: firstChild, otherChild: otherChild)

        let consistencyManager = ConsistencyManager()
        let listener = TestListener(model: testModel)

        addListener(listener, toConsistencyManager: consistencyManager)

        listener.contextClosure = { context in
            XCTAssertEqual(context as? String, "context")
        }

        listener.updateClosure = { _, updates in
            XCTAssertEqual(updates.changedModelIds.count, 2)
            XCTAssertEqual(updates.deletedModelIds.count, 0)
            XCTAssertTrue(updates.changedModelIds.contains("1"))
            XCTAssertTrue(updates.changedModelIds.contains("0"))
        }

        // This should cause both children to update one of their fields
        let updateModel = ProjectionTreeModel(type: .both, id: 1, data: 3, otherData: 3, child: nil, otherChild: nil)

        updateWithNewModel(updateModel, consistencyManager: consistencyManager, context: "context")

        // Should have updated the model of the listener
        if let testModel = listener.model as? ProjectionTreeModel {
            XCTAssertEqual(testModel.child?.data, 3)
            XCTAssertNil(testModel.child?.otherData)
            XCTAssertNil(testModel.otherChild?.data)
            XCTAssertEqual(testModel.otherChild?.otherData, 3)
        } else {
            XCTFail()
        }
    }

    /**
     This tests a tree with one child (.both projection).
     We're going to update this with a new model which has two children with the same id (but different projections).
     We will verify that the original child gets both updates.
     */
    func testUpdatingModelWithTwoProjections() {
        let child = ProjectionTreeModel(type: .both, id: 1, data: 2, otherData: 4, child: nil, otherChild: nil)
        let testModel = ProjectionTreeModel(type: .both, id: 0, data: 1, otherData: 1, child: child, otherChild: nil)

        let consistencyManager = ConsistencyManager()
        let listener = TestListener(model: testModel)

        addListener(listener, toConsistencyManager: consistencyManager)

        listener.contextClosure = { context in
            XCTAssertEqual(context as? String, "context")
        }

        listener.updateClosure = { _, updates in
            XCTAssertEqual(updates.changedModelIds.count, 2)
            XCTAssertEqual(updates.deletedModelIds.count, 0)
            XCTAssertTrue(updates.changedModelIds.contains("1"))
            XCTAssertTrue(updates.changedModelIds.contains("0"))
        }

        // This should cause both children to update one of their fields
        let updateChild = ProjectionTreeModel(type: .data, id: 1, data: 3, otherData: nil, child: nil, otherChild: nil)
        let updateOtherChild = ProjectionTreeModel(type: .otherData, id: 1, data: nil, otherData: 3, child: nil, otherChild: nil)
        let updateModel = ProjectionTreeModel(type: .both, id: 2, data: 5, otherData: 5, child: updateChild, otherChild: updateOtherChild)

        updateWithNewModel(updateModel, consistencyManager: consistencyManager, context: "context")

        // Should have updated the model of the listener
        if let testModel = listener.model as? ProjectionTreeModel {
            // Both fields should have been updated. One from each child model.
            XCTAssertEqual(testModel.child?.data, 3)
            XCTAssertEqual(testModel.child?.otherData, 3)
        } else {
            XCTFail()
        }
    }

    /**
     This tests a tree with one child (.data projection).
     We're going to update this with a .otherData projection.
     Since it doesn't care about any of these changes (nothing has actually changed), this should short curcuit and not call update.
     */
    func testNoUpdateWhenNothingChanges() {
        let child = ProjectionTreeModel(type: .data, id: 1, data: 2, otherData: nil, child: nil, otherChild: nil)
        let testModel = ProjectionTreeModel(type: .both, id: 0, data: 1, otherData: 1, child: child, otherChild: nil)

        let consistencyManager = ConsistencyManager()
        let listener = TestListener(model: testModel)

        addListener(listener, toConsistencyManager: consistencyManager)

        listener.updateClosure = { _, _ in
            XCTFail()
        }

        // No update occurs here, because the children with id=1 are of different projection types that do not overlap.
        let updateModel = ProjectionTreeModel(type: .otherData, id: 1, data: nil, otherData: 5, child: nil, otherChild: nil)

        updateWithNewModel(updateModel, consistencyManager: consistencyManager, context: "context")

        // Nothing should have changed
        if let listenerModel = listener.model as? ProjectionTreeModel {
            XCTAssertEqual(testModel, listenerModel)    
        } else {
            XCTFail()
        }
    }
}
