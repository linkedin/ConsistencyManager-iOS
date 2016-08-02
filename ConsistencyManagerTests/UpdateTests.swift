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


class UpdateTests: ConsistencyManagerTestCase {

    /**
     Test updating the 'root' model of the tree.
     */
    func testUpdateSameModel() {
        for testProjections in [true, false] {
            // Only want even number of models. See TestModelGenerator docs.
            for numberOfModels in 2.stride(through: 40, by: 4) {
                // Branching factor shouldn't really be a factor, so let's just test these two values
                for branchingFactor in 1...2 {
                    let testModel = TestModelGenerator.consistencyManagerModelWithTotalChildren(numberOfModels, branchingFactor: branchingFactor, projectionModel: testProjections) { id in
                        // Let's test this with some ids missing
                        return id % 3 == 0
                    }

                    let consistencyManager = ConsistencyManager()
                    let listener = TestListener(model: testModel)

                    addListener(listener, toConsistencyManager: consistencyManager)

                    let updateModel = TestModel(id: "0", data: -1, children: [], requiredModel: TestRequiredModel(id: "4", data: -1))
                    updateWithNewModel(updateModel, consistencyManager: consistencyManager)

                    // Should have updated the model of the listener
                    if let testModel = testModelFromListenerModel(listener.model) {
                        XCTAssertTrue(testModel == updateModel)
                    } else {
                        XCTFail()
                    }
                }
            }
        }
    }

    /**
     Test that it correctly updates when the listener is a subtree of the model we are updating.
     */
    func testListenerSubtree() {
        for testProjections in [true, false] {
            // Only want even number of models. See TestModelGenerator docs.
            for numberOfModels in 2.stride(through: 100, by: 4) {
                for branchingFactor in 1...5 {
                    let testModel = TestModelGenerator.consistencyManagerModelWithTotalChildren(numberOfModels, branchingFactor: branchingFactor, projectionModel: testProjections) { id in
                        // Let's test this with some ids missing
                        return id % 3 == 0
                    }

                    let consistencyManager = ConsistencyManager()
                    let listener = TestListener(model: testModel)

                    addListener(listener, toConsistencyManager: consistencyManager)

                    // A model with id 0 will be a child of the update model
                    let expectedModel = TestModel(id: "0", data: -1, children: [], requiredModel: TestRequiredModel(id: "4", data: -1))
                    let updateModel = TestModel(id: "-100", data: -100, children: [expectedModel], requiredModel: TestRequiredModel(id: "4", data: -1))

                    updateWithNewModel(updateModel, consistencyManager: consistencyManager)

                    // Should have updated the model of the listener
                    if let testModel = testModelFromListenerModel(listener.model) {
                        XCTAssertTrue(testModel == expectedModel)
                    } else {
                        XCTFail()
                    }
                }
            }
        }
    }

    /**
     If the update model is a subtree of the listener's model, then the listener's model should have been updated to include this subtree.
     */
    func testUpdateModelSubtree() {
        for testProjections in [true, false] {
            // Only want even number of models. See TestModelGenerator docs.
            // Let's skip 2 models since then the listener won't have a subtree
            for numberOfModels in 4.stride(through: 40, by: 4) {
                for branchingFactor in 1...5 {
                    let testModel = TestModelGenerator.consistencyManagerModelWithTotalChildren(numberOfModels, branchingFactor: branchingFactor, projectionModel: testProjections) { id in
                        // Let's make everything we're testing have an id. This will be 0, 2, 6, 10...
                        let includeId: Bool = (id + 2) % 4 == 0
                        return id == 0 || includeId
                    }

                    for replacementId in 2.stride(through: numberOfModels, by: 4) {

                        let consistencyManager = ConsistencyManager()
                        let listener = TestListener(model: testModel)

                        addListener(listener, toConsistencyManager: consistencyManager)
                        let updateModel = TestModel(id: "\(replacementId)", data: -100, children: [], requiredModel: TestRequiredModel(id: "4", data: -1))
                        updateWithNewModel(updateModel, consistencyManager: consistencyManager)

                        // Let's search for the model with the correct id (the one we replaced)
                        // Let's ensure that it has been replaced with the correct model
                        if let testModel = testModelFromListenerModel(listener.model) {
                            if let childModel = testModel.recursiveChildWithId("\(replacementId)") {
                                XCTAssertTrue(childModel == updateModel)
                            } else {
                                XCTFail()
                            }
                        } else {
                            XCTFail()
                        }
                    }
                }
            }
        }
    }

    /**
     If the update model and the listener model have a subtree in common, then the listener model should be updated with this subtree.
     */
    func testUpdateModelListenerCommonSubtree() {
        for testProjections in [true, false] {
            // Only want even number of models. See TestModelGenerator docs.
            // Let's skip 2 models since then the listener won't have a subtree
            for numberOfModels in 4.stride(through: 40, by: 4) {
                for branchingFactor in 1...5 {
                    let testModel = TestModelGenerator.consistencyManagerModelWithTotalChildren(numberOfModels, branchingFactor: branchingFactor, projectionModel: testProjections) { id in
                        // Let's make everything we're testing have an id. This will be 0, 2, 6, 10...
                        let includeId: Bool = (id + 2) % 4 == 0
                        return id == 0 || includeId
                    }

                    // Loop through a bunch of ids we'll look to replace. Note: All these are subtrees of the listener model
                    for replacementId in 2.stride(through: numberOfModels, by: 4) {

                        let consistencyManager = ConsistencyManager()
                        let listener = TestListener(model: testModel)

                        addListener(listener, toConsistencyManager: consistencyManager)
                        let expectedModel = TestModel(id: "\(replacementId)", data: -100, children: [], requiredModel: TestRequiredModel(id: "4", data: -1))
                        let updateModel = TestModel(id: "-200", data: -200, children: [expectedModel], requiredModel: TestRequiredModel(id: "4", data: -1))
                        updateWithNewModel(updateModel, consistencyManager: consistencyManager)

                        // Let's search for the model with the correct id (the one we replaced)
                        // Let's ensure that it has been replaced with the correct model
                        if let testModel = testModelFromListenerModel(listener.model) {
                            if let childModel = testModel.recursiveChildWithId("\(replacementId)") {
                                XCTAssertTrue(childModel == expectedModel)
                            } else {
                                XCTFail()
                            }
                        } else {
                            XCTFail()
                        }
                    }
                }
            }
        }
    }

    /**
     If the listening model has multiple subtrees in common with the update model, everything should be updated.
     */
    func testMultipleUpdatesInOneCall() {
        // This is hard to make generic, so writing a specific test for this one

        // Create a tree with two subtrees
        // Doesn't matter much what's in them, but added some stuff
        let requiredModel = TestRequiredModel(id: "100", data: 100)
        let subtree1 = TestModel(id: "1", data: 1, children: [], requiredModel: requiredModel)
        let subtree2 = TestModel(id: "2", data: 2, children: [subtree1], requiredModel: requiredModel)
        let testModel = TestModel(id: "0", data: 0, children: [subtree1, subtree2], requiredModel: requiredModel)

        // Setup the manager and listener
        let consistencyManager = ConsistencyManager()
        let listener = TestListener(model: testModel)

        addListener(listener, toConsistencyManager: consistencyManager)

        // Now, let's create an update model which has different subtrees, but have the same id
        // Note: I also made one the child of the other this time.
        // Note: Also, the children are in a different order. This shouldn't affect anything.
        let updateSubtree2 = TestModel(id: "2", data: -2, children: [], requiredModel: requiredModel)
        let updateSubtree1 = TestModel(id: "1", data: -1, children: [updateSubtree2], requiredModel: requiredModel)
        let updateTestModel = TestModel(id: "5", data: 0, children: [updateSubtree2, updateSubtree1], requiredModel: requiredModel)

        updateWithNewModel(updateTestModel, consistencyManager: consistencyManager)

        // New model should be the same as testModel but with different children
        let expectedModel = TestModel(id: "0", data: 0, children: [updateSubtree1, updateSubtree2], requiredModel: requiredModel)
        if let model = listener.model as? TestModel {
            XCTAssertEqual(model, expectedModel)
        } else {
            XCTFail()
        }
    }

    func testNoIDsInCommon() {
        for testProjections in [true, false] {
            // Only want even number of models. See TestModelGenerator docs.
            for numberOfModels in 2.stride(through: 40, by: 4) {
                for branchingFactor in 1...5 {
                    for numberOfTestModels in numberOfModels.stride(through: 40, by: 4) {
                        let testModel = TestModelGenerator.consistencyManagerModelWithTotalChildren(numberOfModels, branchingFactor: branchingFactor, projectionModel: testProjections) { id in
                            // Let's make everything we're testing have an id. This will be 0, 2, 6, 10...
                            return id % 3 == 0
                        }

                        let consistencyManager = ConsistencyManager()
                        let listener = TestListener(model: testModel)
                        // We don't want to receive any updates
                        listener.updateClosure = { _ in
                            XCTFail()
                        }

                        addListener(listener, toConsistencyManager: consistencyManager)
                        
                        // This update model will have no ids in common with the previous model
                        let updateModel = TestModelGenerator.testModelWithTotalChildren(numberOfTestModels, branchingFactor: branchingFactor, startingId: numberOfModels) { id in
                            return id % 5 == 0
                        }
                        
                        updateWithNewModel(updateModel, consistencyManager: consistencyManager)
                        
                        if let model = testModelFromListenerModel(listener.model) {
                            // Shouldn't have changed
                            XCTAssertEqual(model, testModelFromListenerModel(testModel))
                        } else {
                            XCTFail()
                        }
                    }
                }
            }
        }
    }
}
