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

class ModelUpdatesTests: ConsistencyManagerTestCase {

    func testReplaceEntireModel() {
        let testModel = TestModel(id: "0", data: 0, children: [], requiredModel: TestRequiredModel(id: "1", data: 0))

        let consistencyManager = ConsistencyManager()
        let listener = TestListener(model: testModel)

        addListener(listener, toConsistencyManager: consistencyManager)

        // Just update the data field
        let updateModel = TestModel(id: "0", data: 4, children: [], requiredModel: TestRequiredModel(id: "1", data: 0))

        var calledUpdateClosure = false
        listener.updateClosure = { model, updates in
            calledUpdateClosure = true
            if let model = model as? TestModel {
                // We should now have just updated one model
                XCTAssertEqual(model, updateModel)
                XCTAssertEqual(updates.changedModelIds.count, 1)
                XCTAssertTrue(updates.changedModelIds.contains("0"))
                XCTAssertEqual(updates.deletedModelIds.count, 0)
            } else {
                XCTFail()
            }
        }

        updateNewModel(updateModel, consistencyManager: consistencyManager)
        
        XCTAssertTrue(calledUpdateClosure)
    }

    func testUpdateOptionalChild() {
        let child = TestModel(id: "2", data: 0, children: [], requiredModel: TestRequiredModel(id: "1", data: 0))
        let testModel = TestModel(id: "0", data: 0, children: [child], requiredModel: TestRequiredModel(id: "1", data: 0))

        let consistencyManager = ConsistencyManager()
        let listener = TestListener(model: testModel)

        addListener(listener, toConsistencyManager: consistencyManager)

        let updateModel = TestModel(id: "2", data: 4, children: [], requiredModel: TestRequiredModel(id: "4", data: 0))

        var calledUpdateClosure = false
        listener.updateClosure = { model, updates in
            calledUpdateClosure = true
            // We should now have updated two models (parent and child)
            XCTAssertEqual(updates.changedModelIds.count, 2)
            XCTAssertTrue(updates.changedModelIds.contains("0"))
            XCTAssertTrue(updates.changedModelIds.contains("2"))
            XCTAssertEqual(updates.deletedModelIds.count, 0)
        }

        updateNewModel(updateModel, consistencyManager: consistencyManager)

        XCTAssertTrue(calledUpdateClosure)
    }

    func testUpdateRequiredChild() {
        let child = TestModel(id: "2", data: 0, children: [], requiredModel: TestRequiredModel(id: "3", data: 0))
        let testModel = TestModel(id: "0", data: 0, children: [child], requiredModel: TestRequiredModel(id: "1", data: 0))

        let consistencyManager = ConsistencyManager()
        let listener = TestListener(model: testModel)

        addListener(listener, toConsistencyManager: consistencyManager)

        let updateModel = TestRequiredModel(id: "1", data: 4)

        var calledUpdateClosure = false
        listener.updateClosure = { model, updates in
            calledUpdateClosure = true
            // We should now have updated two models (parent and child)
            XCTAssertEqual(updates.changedModelIds.count, 2)
            XCTAssertTrue(updates.changedModelIds.contains("0"))
            XCTAssertTrue(updates.changedModelIds.contains("1"))
            XCTAssertEqual(updates.deletedModelIds.count, 0)
        }

        updateNewModel(updateModel, consistencyManager: consistencyManager)

        XCTAssertTrue(calledUpdateClosure)
    }

    func testUpdateRecurringChild() {
        let child = TestModel(id: "2", data: 0, children: [], requiredModel: TestRequiredModel(id: "1", data: 0))
        let secondChild = TestModel(id: "3", data: 0, children: [], requiredModel: TestRequiredModel(id: "5", data: 0))
        let testModel = TestModel(id: "0", data: 0, children: [child, child, secondChild], requiredModel: TestRequiredModel(id: "1", data: 0))

        let consistencyManager = ConsistencyManager()
        let listener = TestListener(model: testModel)

        addListener(listener, toConsistencyManager: consistencyManager)

        let updateModel = TestRequiredModel(id: "1", data: 4)

        var calledUpdateClosure = false
        listener.updateClosure = { model, updates in
            calledUpdateClosure = true
            // We should now have a bunch of updated models. Two children and their parents.
            XCTAssertEqual(updates.changedModelIds.count, 3)
            XCTAssertTrue(updates.changedModelIds.contains("0"))
            XCTAssertTrue(updates.changedModelIds.contains("1"))
            XCTAssertTrue(updates.changedModelIds.contains("2"))
            XCTAssertEqual(updates.deletedModelIds.count, 0)
        }

        updateNewModel(updateModel, consistencyManager: consistencyManager)

        XCTAssertTrue(calledUpdateClosure)
    }

    func testUpdateSubtree() {
        let child = TestModel(id: "2", data: 0, children: [], requiredModel: TestRequiredModel(id: "6", data: 0))
        let secondChild = TestModel(id: "3", data: 0, children: [], requiredModel: TestRequiredModel(id: "5", data: 0))
        let testModel = TestModel(id: "0", data: 0, children: [child, child, secondChild], requiredModel: TestRequiredModel(id: "1", data: 0))

        let consistencyManager = ConsistencyManager()
        let listener = TestListener(model: testModel)

        addListener(listener, toConsistencyManager: consistencyManager)

        // Note: Here we're updating 2 and 6
        let newChild = TestModel(id: "2", data: 3, children: [], requiredModel: TestRequiredModel(id: "6", data: 2))
        // This is contained in another model
        let updateModel = TestModel(id: "7", data: 3, children: [newChild], requiredModel: TestRequiredModel(id: "5", data: 0))

        var calledUpdateClosure = false
        listener.updateClosure = { model, updates in
            calledUpdateClosure = true
            // We've updated one whole tree
            XCTAssertEqual(updates.changedModelIds.count, 3)
            XCTAssertTrue(updates.changedModelIds.contains("0"))
            XCTAssertTrue(updates.changedModelIds.contains("2"))
            XCTAssertTrue(updates.changedModelIds.contains("6"))
            XCTAssertEqual(updates.deletedModelIds.count, 0)
        }

        updateNewModel(updateModel, consistencyManager: consistencyManager)

        XCTAssertTrue(calledUpdateClosure)
    }

    func testUpdateEntireModelWithSubtree() {
        let child = TestModel(id: "2", data: 0, children: [], requiredModel: TestRequiredModel(id: "6", data: 0))
        let secondChild = TestModel(id: "3", data: 0, children: [], requiredModel: TestRequiredModel(id: "5", data: 0))
        let testModel = TestModel(id: "0", data: 0, children: [child, child, secondChild], requiredModel: TestRequiredModel(id: "1", data: 0))

        let consistencyManager = ConsistencyManager()
        let listener = TestListener(model: testModel)

        addListener(listener, toConsistencyManager: consistencyManager)

        // Note: This is the entire model
        let newChild = TestModel(id: "0", data: 3, children: [], requiredModel: TestRequiredModel(id: "6", data: 2))
        // This is contained in another model
        let updateModel = TestModel(id: "7", data: 3, children: [newChild], requiredModel: TestRequiredModel(id: "5", data: 0))

        var calledUpdateClosure = false
        listener.updateClosure = { model, updates in
            calledUpdateClosure = true
            // We've updated the whole model, but also 6 changed data, so we should have 2 changes
            // Note though: though 2 technically changed, it's no longer in the tree so we won't report it as changed
            XCTAssertEqual(updates.changedModelIds.count, 2)
            XCTAssertTrue(updates.changedModelIds.contains("0"))
            XCTAssertTrue(updates.changedModelIds.contains("6"))
            XCTAssertEqual(updates.deletedModelIds.count, 0)
        }

        updateNewModel(updateModel, consistencyManager: consistencyManager)

        XCTAssertTrue(calledUpdateClosure)
    }

    func testUpdateWithSubupdates() {
        let subchild = TestModel(id: "4", data: 0, children: [], requiredModel: TestRequiredModel(id: "6", data: 0))
        let child = TestModel(id: "2", data: 0, children: [subchild], requiredModel: TestRequiredModel(id: "3", data: 0))
        let testModel = TestModel(id: "0", data: 0, children: [child], requiredModel: TestRequiredModel(id: "1", data: 0))

        let consistencyManager = ConsistencyManager()
        let listener = TestListener(model: testModel)

        addListener(listener, toConsistencyManager: consistencyManager)

        // In this update we are:
        // - Changing 2's child (so 2 should be an update)
        // - Changing the data of 6 (so 6 should be an update, and 4 should be a cascaded update)
        let updateChild = TestModel(id: "4", data: 0, children: [], requiredModel: TestRequiredModel(id: "6", data: 4))
        let updateModel = TestModel(id: "2", data: 0, children: [updateChild], requiredModel: TestRequiredModel(id: "7", data: 0))

        var calledUpdateClosure = false
        listener.updateClosure = { model, updates in
            calledUpdateClosure = true
            // We should now have a bunch of updates - parent, child, subchild and required model of subchild
            // 7 should not be included in the update since it's no a changed model
            XCTAssertEqual(updates.changedModelIds.count, 4)
            XCTAssertTrue(updates.changedModelIds.contains("0"))
            XCTAssertTrue(updates.changedModelIds.contains("2"))
            XCTAssertTrue(updates.changedModelIds.contains("4"))
            XCTAssertTrue(updates.changedModelIds.contains("6"))
            XCTAssertEqual(updates.deletedModelIds.count, 0)
        }

        updateNewModel(updateModel, consistencyManager: consistencyManager)

        XCTAssertTrue(calledUpdateClosure)
    }

    func testUpdateWithSubupdatesAfterChange() {
        let subchild = TestModel(id: "4", data: 0, children: [], requiredModel: TestRequiredModel(id: "6", data: 0))
        let child = TestModel(id: "2", data: 0, children: [subchild], requiredModel: TestRequiredModel(id: "3", data: 0))
        let testModel = TestModel(id: "0", data: 0, children: [child], requiredModel: TestRequiredModel(id: "1", data: 0))

        let consistencyManager = ConsistencyManager()
        let listener = TestListener(model: testModel)

        addListener(listener, toConsistencyManager: consistencyManager)

        // First, we're going to change it so two new children (7+8)
        let initialSubchildUpdate = TestModel(id: "7", data: 0, children: [], requiredModel: TestRequiredModel(id: "8", data: 0))
        let initialUpdateModel = TestModel(id: "2", data: 0, children: [initialSubchildUpdate], requiredModel: TestRequiredModel(id: "3", data: 0))
        // Now, let's do an update so it changes
        updateNewModel(initialUpdateModel, consistencyManager: consistencyManager)

        // Now, let's change the new model, but with it contained in a subtree
        // Here were updating both 2 and 7. We expect both of these to register as updates
        // We're verifying that we're correctly listening to changes on 7 and that updates to 8 get correctly noticed
        let updateModel = TestModel(id: "7", data: 2, children: [], requiredModel: TestRequiredModel(id: "8", data: 4))

        var calledUpdateClosure = false
        listener.updateClosure = { model, updates in
            calledUpdateClosure = true
            // We should now have a bunch of updates - parent, child, subchild and required model of subchild
            // 7 should not be included in the update since it's not a changed model
            XCTAssertEqual(updates.changedModelIds.count, 4)
            XCTAssertTrue(updates.changedModelIds.contains("0"))
            XCTAssertTrue(updates.changedModelIds.contains("2"))
            XCTAssertTrue(updates.changedModelIds.contains("7"))
            XCTAssertTrue(updates.changedModelIds.contains("8"))
            XCTAssertEqual(updates.deletedModelIds.count, 0)
        }

        updateNewModel(updateModel, consistencyManager: consistencyManager)

        XCTAssertTrue(calledUpdateClosure)
    }

    // MARK: Delete

    func testDeleteEntireModel() {
        let testModel = TestModel(id: "0", data: 0, children: [], requiredModel: TestRequiredModel(id: "1", data: 0))

        let consistencyManager = ConsistencyManager()
        let listener = TestListener(model: testModel)

        addListener(listener, toConsistencyManager: consistencyManager)

        let modelToDelete = testModel

        var calledUpdateClosure = false
        listener.updateClosure = { model, updates in
            calledUpdateClosure = true
            // We've deleted the whole model, so just one change
            XCTAssertEqual(updates.changedModelIds.count, 0)
            XCTAssertEqual(updates.deletedModelIds.count, 1)
            XCTAssertTrue(updates.deletedModelIds.contains("0"))
        }

        deleteModel(modelToDelete, consistencyManager: consistencyManager)

        XCTAssertTrue(calledUpdateClosure)
    }

    func testCascadingDeleteEntireModel() {
        let testModel = TestModel(id: "0", data: 0, children: [], requiredModel: TestRequiredModel(id: "1", data: 0))

        let consistencyManager = ConsistencyManager()
        let listener = TestListener(model: testModel)

        addListener(listener, toConsistencyManager: consistencyManager)

        let modelToDelete = TestRequiredModel(id: "1", data: 0)

        var calledUpdateClosure = false
        listener.updateClosure = { model, updates in
            calledUpdateClosure = true
            // We've deleted both models, so both should be deleted
            XCTAssertEqual(updates.changedModelIds.count, 0)
            XCTAssertEqual(updates.deletedModelIds.count, 2)
            XCTAssertTrue(updates.deletedModelIds.contains("0"))
            XCTAssertTrue(updates.deletedModelIds.contains("1"))
        }

        deleteModel(modelToDelete, consistencyManager: consistencyManager)

        XCTAssertTrue(calledUpdateClosure)
    }

    func testDeleteOptionalModel() {
        let child = TestModel(id: "2", data: 0, children: [], requiredModel: TestRequiredModel(id: "1", data: 0))
        let testModel = TestModel(id: "0", data: 0, children: [child], requiredModel: TestRequiredModel(id: "1", data: 0))

        let consistencyManager = ConsistencyManager()
        let listener = TestListener(model: testModel)

        addListener(listener, toConsistencyManager: consistencyManager)

        let modelToDelete = child

        var calledUpdateClosure = false
        listener.updateClosure = { model, updates in
            calledUpdateClosure = true
            // We've deleted a child model, which caused the parent model to update
            XCTAssertEqual(updates.changedModelIds.count, 1)
            XCTAssertTrue(updates.changedModelIds.contains("0"))
            XCTAssertEqual(updates.deletedModelIds.count, 1)
            XCTAssertTrue(updates.deletedModelIds.contains("2"))
        }

        deleteModel(modelToDelete, consistencyManager: consistencyManager)

        XCTAssertTrue(calledUpdateClosure)
    }

    func testCascadingDeleteSubmodel() {
        let child = TestModel(id: "2", data: 0, children: [], requiredModel: TestRequiredModel(id: "3", data: 0))
        let testModel = TestModel(id: "0", data: 0, children: [child], requiredModel: TestRequiredModel(id: "1", data: 0))

        let consistencyManager = ConsistencyManager()
        let listener = TestListener(model: testModel)

        addListener(listener, toConsistencyManager: consistencyManager)

        let modelToDelete = TestRequiredModel(id: "3", data: 0)

        var calledUpdateClosure = false
        listener.updateClosure = { model, updates in
            calledUpdateClosure = true
            // We've deleted a child model, which caused the parent model to update
            // We also should include the actual deleted model
            XCTAssertEqual(updates.changedModelIds.count, 1)
            XCTAssertTrue(updates.changedModelIds.contains("0"))
            XCTAssertEqual(updates.deletedModelIds.count, 2)
            XCTAssertTrue(updates.deletedModelIds.contains("2"))
            XCTAssertTrue(updates.deletedModelIds.contains("3"))
        }

        deleteModel(modelToDelete, consistencyManager: consistencyManager)

        XCTAssertTrue(calledUpdateClosure)
    }

    func testDeleteRecurringChild() {
        let child = TestModel(id: "2", data: 0, children: [], requiredModel: TestRequiredModel(id: "3", data: 0))
        let otherChild = TestModel(id: "4", data: 0, children: [child], requiredModel: TestRequiredModel(id: "5", data: 0))
        let testModel = TestModel(id: "0", data: 0, children: [child, child, otherChild], requiredModel: TestRequiredModel(id: "1", data: 0))

        let consistencyManager = ConsistencyManager()
        let listener = TestListener(model: testModel)

        addListener(listener, toConsistencyManager: consistencyManager)

        let modelToDelete = TestRequiredModel(id: "3", data: 0)

        var calledUpdateClosure = false
        listener.updateClosure = { model, updates in
            calledUpdateClosure = true
            // We've deleted a child model, which caused the parent model to update
            // We also should include the actual deleted model
            XCTAssertEqual(updates.changedModelIds.count, 2)
            XCTAssertTrue(updates.changedModelIds.contains("0"))
            XCTAssertTrue(updates.changedModelIds.contains("4"))
            XCTAssertEqual(updates.deletedModelIds.count, 2)
            XCTAssertTrue(updates.deletedModelIds.contains("2"))
            XCTAssertTrue(updates.deletedModelIds.contains("3"))
            if let model = model as? TestModel {
                XCTAssertEqual(model.children.count, 1)
                XCTAssertEqual(model.children[0].id, "4")
                XCTAssertEqual(model.children[0].children.count, 0)
            } else {
                XCTFail()
            }
        }

        deleteModel(modelToDelete, consistencyManager: consistencyManager)

        XCTAssertTrue(calledUpdateClosure)
    }
}
