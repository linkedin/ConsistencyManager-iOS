// © 2016 LinkedIn Corp. All rights reserved.
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at  http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.

import XCTest
@testable import ConsistencyManager

/**
 This test suite focuses on the pauseListeningForUpdates and resumeListeningForUpdates methods in ConsistencyManager.swift.
 This tests behavior with updates, deletes, multiple listeners, batch updates, etc.
 */
class PauseListenerTests: ConsistencyManagerTestCase {
    /**
     This provides some reusable code for generating a test model with many children.
     */
    func setUpListeners(quantity: Int, projectionModel: Bool) -> ([TestListener], ConsistencyManager) {
        // We generate models with varying lists of children for more thorough testing.
        let testModel = TestModelGenerator.consistencyManagerModelWithTotalChildren(10, branchingFactor: 3, projectionModel: projectionModel) { id in
            return true
        }

        let consistencyManager = ConsistencyManager()
        var testListeners = [TestListener]()

        for _ in 0...quantity {
            let listener = TestListener(model: testModel)
            addListener(listener, toConsistencyManager: consistencyManager)
            testListeners.append(listener)
        }
        return (testListeners, consistencyManager)
    }

    /**
     This initial test simply makes updates to a listener while it's
     paused and then makes sure that it gets those updates only after
     it resumes listening.
     */
    func testUpdatesBetweenPausingAndResuming() {
        for testProjections in [true, false] {
            let (listeners, consistencyManager) = setUpListeners(1, projectionModel: testProjections)
            let listener = listeners[0]

            var numberOfUpdates = 0
            var modelUpdates = ModelUpdates(changedModelIds: [], deletedModelIds: [])
            listener.updateClosure = { (_, updates) in
                numberOfUpdates += 1
                modelUpdates = updates
                XCTAssertTrue(NSThread.currentThread().isMainThread)
            }
            var contextString: String?
            listener.contextClosure = { context in
                if let context = context as? String {
                    contextString = context
                }
            }

            // Current models before the update
            var testModel = testModelFromListenerModel(listener.model)!
            XCTAssertEqual(testModel.children[0].data, 2)
            XCTAssertEqual(testModel.children[1].data, 4)
            XCTAssertEqual(modelUpdates.changedModelIds, [])
            XCTAssertEqual(modelUpdates.deletedModelIds, [])
            XCTAssertEqual(numberOfUpdates, 0)

            XCTAssertFalse(consistencyManager.isPaused(listener))
            pauseListeningForUpdates(listener, consistencyManager: consistencyManager)
            XCTAssertTrue(consistencyManager.isPaused(listener))
            // Pausing again shouldn't affect anything. We should still only get one callback.
            pauseListeningForUpdates(listener, consistencyManager: consistencyManager)
            XCTAssertTrue(consistencyManager.isPaused(listener))
            // Similarly, adding the listener again shouldn't affect anything, as this does not resume the listening of the listener.
            addListener(listener, toConsistencyManager: consistencyManager)

            testModel = testModelFromListenerModel(listener.model)!
            let updateModel1 = TestModel(id: "2", data: -2, children: [], requiredModel: TestRequiredModel(id: "21", data: -1))
            let updateModel2 = TestModel(id: "4", data: -4, children: [], requiredModel: TestRequiredModel(id: "21", data: -1))
            let batchModel = BatchUpdateModel(models: [updateModel1, updateModel2])
            updateWithNewModel(batchModel, consistencyManager: consistencyManager, context: "change")

            testModel = testModelFromListenerModel(listener.model)!
            // Updates have happened, but we didn't listen for them.
            XCTAssertEqual(testModel.children[0].data, 2)
            XCTAssertEqual(testModel.children[1].data, 4)
            XCTAssertEqual(modelUpdates.changedModelIds, [])
            XCTAssertEqual(modelUpdates.deletedModelIds, [])
            XCTAssertEqual(numberOfUpdates, 0)

            let updateModel3 = TestModel(id: "2", data: -5, children: [], requiredModel: TestRequiredModel(id: "21", data: -1))
            let updateModel4 = TestModel(id: "4", data: -6, children: [], requiredModel: TestRequiredModel(id: "21", data: -1))
            let batchModel2 = BatchUpdateModel(models: [updateModel3, updateModel4])
            updateWithNewModel(batchModel2, consistencyManager: consistencyManager, context: "change2")

            testModel = testModelFromListenerModel(listener.model)!
            // Updates have happened, but we didn't listen for them.
            XCTAssertEqual(testModel.children[0].data, 2)
            XCTAssertEqual(testModel.children[1].data, 4)
            XCTAssertEqual(modelUpdates.changedModelIds, [])
            XCTAssertEqual(modelUpdates.deletedModelIds, [])
            XCTAssertNil(contextString)
            XCTAssertEqual(numberOfUpdates, 0)

            // Resume listening for changes, and get all previous changes.
            resumeListeningForUpdates(listener, consistencyManager: consistencyManager)

            // Both models were updated, and now we have listened to those updates.
            testModel = testModelFromListenerModel(listener.model)!
            XCTAssertEqual(testModel.children[0].data, -5)
            XCTAssertEqual(testModel.children[1].data, -6)
            XCTAssertEqual(modelUpdates.changedModelIds, ["0","2","4"]) // O is the root, so it's changed as well
            XCTAssertEqual(modelUpdates.deletedModelIds, [])
            XCTAssertEqual(contextString, "change2") // Only the last context is received.
            XCTAssertEqual(numberOfUpdates, 1) // We only count the final batch update to the models that occurs after we resume listening.
        }
    }

    /**
     We have two listeners. The second one pauses, and then some changes to its models occur.
     The first listener should pick these up, but not the second.
     After the second listener resumes listening it should also pick these changes up.
     We keep track of the number of updates (delegate method callbacks) for each listener.
     */
    func testMultipleListenersWithPausingAndResuming() {
        for testProjections in [true, false] {
            var (listeners, consistencyManager) = setUpListeners(2, projectionModel: testProjections)
            let activeListener = listeners[0]
            let pausedListener = listeners[1]

            var numberOfUpdates1 = 0
            var numberOfUpdates2 = 0
            var modelUpdatesPausedListener = ModelUpdates(changedModelIds: [], deletedModelIds: [])
            activeListener.updateClosure = { (_, updates) in
                numberOfUpdates1 += 1
                XCTAssertTrue(NSThread.currentThread().isMainThread)
            }
            pausedListener.updateClosure = { (_, updates) in
                numberOfUpdates2 += 1
                modelUpdatesPausedListener = updates
                XCTAssertTrue(NSThread.currentThread().isMainThread)
            }

            // Current models before the update
            for listener in [activeListener, pausedListener] {
                let testModel = testModelFromListenerModel(listener.model)!
                XCTAssertEqual(testModel.children[0].data, 2)
                XCTAssertEqual(testModel.children[1].data, 4)
                XCTAssertEqual(numberOfUpdates1, 0)
            }

            XCTAssertFalse(consistencyManager.isPaused(pausedListener))
            pauseListeningForUpdates(pausedListener, consistencyManager: consistencyManager)
            XCTAssertTrue(consistencyManager.isPaused(pausedListener))

            let updateModel1a = TestModel(id: "2", data: -22, children: [], requiredModel: TestRequiredModel(id: "21", data: -1))
            let updateModel2a = TestModel(id: "4", data: -44, children: [], requiredModel: TestRequiredModel(id: "21", data: -1))
            let batchModel1 = BatchUpdateModel(models: [updateModel1a, updateModel2a])

            updateWithNewModel(batchModel1, consistencyManager: consistencyManager)

            let updateModel1b = TestModel(id: "2", data: -2, children: [], requiredModel: TestRequiredModel(id: "21", data: -1))
            let updateModel2b = TestModel(id: "4", data: -4, children: [], requiredModel: TestRequiredModel(id: "21", data: -1))
            let batchModel2 = BatchUpdateModel(models: [updateModel1b, updateModel2b])
            // Updating the models
            updateWithNewModel(batchModel2, consistencyManager: consistencyManager)

            // After the first two updates
            var testModel1 = testModelFromListenerModel(activeListener.model)!
            XCTAssertEqual(testModel1.children[0].data, -2)
            XCTAssertEqual(testModel1.children[1].data, -4)
            XCTAssertEqual(numberOfUpdates1, 2)

            var testModel2 = testModelFromListenerModel(pausedListener.model)!
            XCTAssertEqual(testModel2.children[0].data, 2)
            XCTAssertEqual(testModel2.children[1].data, 4)
            XCTAssertEqual(modelUpdatesPausedListener.changedModelIds, [])
            XCTAssertEqual(modelUpdatesPausedListener.deletedModelIds, [])
            XCTAssertEqual(numberOfUpdates2, 0)

            // Resume listening for changes, and get all previous changes in a batch update
            resumeListeningForUpdates(pausedListener, consistencyManager: consistencyManager)
            XCTAssertFalse(consistencyManager.isPaused(pausedListener))

            testModel2 = testModelFromListenerModel(pausedListener.model)!
            XCTAssertEqual(testModel2.children[0].data, -2)
            XCTAssertEqual(testModel2.children[1].data, -4)
            XCTAssertEqual(modelUpdatesPausedListener.changedModelIds, ["0","2","4"])
            XCTAssertEqual(modelUpdatesPausedListener.deletedModelIds, [])
            XCTAssertEqual(numberOfUpdates2, 1)

            let updateModel3 = TestModel(id: "2", data: -5, children: [], requiredModel: TestRequiredModel(id: "21", data: -1))
            let updateModel4 = TestModel(id: "4", data: -6, children: [], requiredModel: TestRequiredModel(id: "21", data: -1))
            let batchModel3 = BatchUpdateModel(models: [updateModel3, updateModel4])
            updateWithNewModel(batchModel3, consistencyManager: consistencyManager)

            testModel1 = testModelFromListenerModel(activeListener.model)!
            testModel2 = testModelFromListenerModel(pausedListener.model)!

            // After the third update
            XCTAssertEqual(testModel1.children[0].data, -5)
            XCTAssertEqual(testModel1.children[1].data, -6)
            XCTAssertEqual(numberOfUpdates1, 3)
            XCTAssertEqual(testModel2.children[0].data, -5)
            XCTAssertEqual(testModel2.children[1].data, -6)
            XCTAssertEqual(modelUpdatesPausedListener.changedModelIds, ["0","2","4"])
            XCTAssertEqual(modelUpdatesPausedListener.deletedModelIds, [])
            XCTAssertEqual(numberOfUpdates2, 2)
        }
    }

    /**
     We have a registered listener. It pauses and then immediately resumes.
     There should not be any updates to pick up.
     */
    func testNoChangesWhilePaused() {
        for testProjections in [true, false] {
            let (listeners, consistencyManager) = setUpListeners(1, projectionModel: testProjections)
            let listener = listeners[0]

            var numberOfUpdates = 0
            var modelUpdates = ModelUpdates(changedModelIds: [], deletedModelIds: [])
            listener.updateClosure = { (_, updates) in
                numberOfUpdates += 1
                modelUpdates = updates
                XCTAssertTrue(NSThread.currentThread().isMainThread)
            }

            // Current model before the update
            var testModel = testModelFromListenerModel(listener.model)!
            XCTAssertEqual(testModel.children[0].data, 2)
            XCTAssertEqual(numberOfUpdates, 0)

            XCTAssertFalse(consistencyManager.isPaused(listener))
            pauseListeningForUpdates(listener, consistencyManager: consistencyManager)
            XCTAssertTrue(consistencyManager.isPaused(listener))
            resumeListeningForUpdates(listener, consistencyManager: consistencyManager)
            XCTAssertFalse(consistencyManager.isPaused(listener))

            // Current models before the update
            testModel = testModelFromListenerModel(listener.model)!
            XCTAssertEqual(testModel.children[0].data, 2)
            XCTAssertEqual(modelUpdates.changedModelIds, [])
            XCTAssertEqual(modelUpdates.deletedModelIds, [])
            XCTAssertEqual(numberOfUpdates, 0)
        }
    }

    /**
     We have a registered listener. It pauses.
     An update happens that results in no changes to the model. Listening resumes.
     There should not be any updates to pick up.
     */
    func testInconsequentialChangeDuringUpdate() {
        var testModel = TestModel(id: "0", data: 0, children: [], requiredModel: TestRequiredModel(id: "1", data: 0))
        let consistencyManager = ConsistencyManager()
        let listener = TestListener(model: testModel)
        addListener(listener, toConsistencyManager: consistencyManager)

        var numberOfUpdates = 0
        var modelUpdates = ModelUpdates(changedModelIds: [], deletedModelIds: [])
        listener.updateClosure = { (_, updates) in
            numberOfUpdates += 1
            modelUpdates = updates
            XCTAssertTrue(NSThread.currentThread().isMainThread)
        }

        // Current model before the update
        XCTAssertEqual(testModel.requiredModel.data, 0)
        XCTAssertEqual(numberOfUpdates, 0)

        XCTAssertFalse(consistencyManager.isPaused(listener))
        pauseListeningForUpdates(listener, consistencyManager: consistencyManager)
        XCTAssertTrue(consistencyManager.isPaused(listener))

        let updateModel = testModel
        updateWithNewModel(updateModel, consistencyManager: consistencyManager, context: nil)

        testModel = listener.model as! TestModel
        XCTAssertEqual(testModel.requiredModel.data, 0)
        XCTAssertEqual(modelUpdates.changedModelIds, [])
        XCTAssertEqual(modelUpdates.deletedModelIds, [])
        XCTAssertEqual(numberOfUpdates, 0)

        resumeListeningForUpdates(listener, consistencyManager: consistencyManager)
        XCTAssertFalse(consistencyManager.isPaused(listener))
        testModel = listener.model as! TestModel
        XCTAssertEqual(testModel.requiredModel.data, 0)
        XCTAssertEqual(modelUpdates.changedModelIds, [])
        XCTAssertEqual(modelUpdates.deletedModelIds, [])
        XCTAssertEqual(numberOfUpdates, 0)
    }

    /**
     We have two registered listeners.
     Between the first listener pausing and resuming, there are two updates to the models,
     the second of which undoes the first, leaving no overall change to the model.
     We ensure that the delegate function (onModelUpdated) is not called when
     the listener starts listening again.
     Also, we ensure that the changelist is left as empty when the paused listener resumes listening.
     */
    func testChangesThatCancelOut() {
        for testProjections in [true, false] {
            let model = TestModelGenerator.consistencyManagerModelWithTotalChildren(2, branchingFactor: 0, projectionModel: testProjections) { _ in
                return true
            }
            let consistencyManager = ConsistencyManager()
            let pausedListener = TestListener(model: model)
            let activeListener = TestListener(model: model)
            addListener(pausedListener, toConsistencyManager: consistencyManager)
            addListener(activeListener, toConsistencyManager: consistencyManager)

            var numberOfUpdatesToPausedListener = 0
            var modelUpdatesPausedListener = ModelUpdates(changedModelIds: [], deletedModelIds: [])
            pausedListener.updateClosure = { (_, updates) in
                numberOfUpdatesToPausedListener += 1
                modelUpdatesPausedListener = updates
                XCTAssertTrue(NSThread.currentThread().isMainThread)
            }
            var contextStringSavedToPausedListener: String?
            pausedListener.contextClosure = { context in
                if let context = context as? String {
                    contextStringSavedToPausedListener = context
                }
            }
            var numberOfUpdatesToActiveListener = 0
            var modelUpdatesActiveListener = ModelUpdates(changedModelIds: [], deletedModelIds: [])
            activeListener.updateClosure = { (_, updates) in
                numberOfUpdatesToActiveListener += 1
                modelUpdatesActiveListener = updates
                XCTAssertTrue(NSThread.currentThread().isMainThread)
            }
            var contextStringSavedToActiveListener: String?
            activeListener.contextClosure = { context in
                if let context = context as? String {
                    contextStringSavedToActiveListener = context
                }
            }

            // Current model before the update
            var testModel = testModelFromListenerModel(pausedListener.model)!
            XCTAssertEqual(testModel.requiredModel.data, 0)
            XCTAssertEqual(numberOfUpdatesToPausedListener, 0)
            testModel = testModelFromListenerModel(activeListener.model)!
            XCTAssertEqual(testModel.requiredModel.data, 0)
            XCTAssertEqual(numberOfUpdatesToActiveListener, 0)

            XCTAssertFalse(consistencyManager.isPaused(pausedListener))
            pauseListeningForUpdates(pausedListener, consistencyManager: consistencyManager)
            XCTAssertTrue(consistencyManager.isPaused(pausedListener))

            let updateModel = TestModel(id: "0", data: 0, children: [], requiredModel: TestRequiredModel(id: "1", data: -5))
            updateWithNewModel(updateModel, consistencyManager: consistencyManager, context: "firstChange")

            // Update has happened, but we didn't listen for it on the first listener.
            testModel = testModelFromListenerModel(pausedListener.model)!
            XCTAssertEqual(testModel.requiredModel.data, 0)
            XCTAssertEqual(numberOfUpdatesToPausedListener, 0)
            XCTAssertEqual(modelUpdatesPausedListener.changedModelIds, [])
            XCTAssertEqual(modelUpdatesPausedListener.deletedModelIds, [])
            XCTAssertNil(contextStringSavedToPausedListener)
            // We listened on the second listener.
            testModel = testModelFromListenerModel(activeListener.model)!
            XCTAssertEqual(testModel.requiredModel.data, -5)
            XCTAssertEqual(numberOfUpdatesToActiveListener, 1)
            XCTAssertEqual(modelUpdatesActiveListener.changedModelIds, ["0","1"])
            XCTAssertEqual(modelUpdatesActiveListener.deletedModelIds, [])
            XCTAssertEqual(contextStringSavedToActiveListener!, "firstChange")

            let undoUpdateModel = TestModel(id: "0", data: 0, children: [], requiredModel: TestRequiredModel(id: "1", data: 0))
            updateWithNewModel(undoUpdateModel, consistencyManager: consistencyManager, context: "undoingChange")

            // Update has happened, but we didn't listen for it on the first listener.
            testModel = testModelFromListenerModel(pausedListener.model)!
            XCTAssertEqual(testModel.requiredModel.data, 0)
            XCTAssertEqual(numberOfUpdatesToPausedListener, 0)
            XCTAssertEqual(modelUpdatesPausedListener.changedModelIds, [])
            XCTAssertEqual(modelUpdatesPausedListener.deletedModelIds, [])
            XCTAssertNil(contextStringSavedToPausedListener)
            // We listened on the second listener.
            testModel = testModelFromListenerModel(activeListener.model)!
            XCTAssertEqual(testModel.requiredModel.data, 0)
            XCTAssertEqual(numberOfUpdatesToActiveListener, 2)
            XCTAssertEqual(modelUpdatesActiveListener.changedModelIds, ["0","1"])
            XCTAssertEqual(modelUpdatesActiveListener.deletedModelIds, [])
            XCTAssertEqual(contextStringSavedToActiveListener!, "undoingChange")

            // Resume listening for changes, and get all previous changes
            resumeListeningForUpdates(pausedListener, consistencyManager: consistencyManager)
            XCTAssertFalse(consistencyManager.isPaused(pausedListener))

            // Make sure that we received no updates on the paused listener.
            testModel = testModelFromListenerModel(pausedListener.model)!
            XCTAssertEqual(testModel.requiredModel.data, 0)
            XCTAssertEqual(numberOfUpdatesToPausedListener, 0)
            XCTAssertEqual(modelUpdatesPausedListener.changedModelIds, [])
            XCTAssertEqual(modelUpdatesPausedListener.deletedModelIds, [])
            XCTAssertNil(contextStringSavedToPausedListener)

            testModel = testModelFromListenerModel(activeListener.model)!
            XCTAssertEqual(testModel.requiredModel.data, 0)
            XCTAssertEqual(numberOfUpdatesToActiveListener, 2)
            XCTAssertEqual(modelUpdatesActiveListener.changedModelIds, ["0","1"])
            XCTAssertEqual(modelUpdatesActiveListener.deletedModelIds, [])
            XCTAssertEqual(contextStringSavedToActiveListener!, "undoingChange")
        }
    }

    /**
     We have one registed listener and a model with various children and required models.
     After the listener is paused, various deletes and model updates occur in succession, some of which cancel
     each other out.
     We confirm at the end that only the persistent deletes and changes stay in the changelist when the listener
     resumes listening.

         0
       / | \
      2  4  1r
     /
     3r

     Pause

     Delete 3 -> nil
     - 2 is Deleted
     Readd 2 -> 2' and Update 1 -> 1'
     Update 1 -> 1
     Update 2 -> 2''
     Add 3 -> 3' as a required child of 2
     Update 3 -> 3

     Resume
     Result should be: Deleted [], and Updated [0,2]

         0
       / | \
      2' 4  1r
     /
     3r
     */
    func testSomeChangesThatCancelOut() {
        let child = TestModel(id: "2", data: 0, children: [], requiredModel: TestRequiredModel(id: "3", data: 0))
        let otherChild = TestModel(id: "4", data: 0, children: [], requiredModel: TestRequiredModel(id: nil, data: 0))
        let testModel = TestModel(id: "0", data: 0, children: [child, otherChild], requiredModel: TestRequiredModel(id: "1", data: 0))
        let consistencyManager = ConsistencyManager()
        let pausedListener = TestListener(model: testModel)
        addListener(pausedListener, toConsistencyManager: consistencyManager)

        var contextStringSavedToPausedListener: String?
        pausedListener.contextClosure = { context in
            if let context = context as? String {
                contextStringSavedToPausedListener = context
            }
        }

        var calledUpdateClosure = false
        pausedListener.updateClosure = { model, updates in
            calledUpdateClosure = true
            XCTAssertEqual(updates.changedModelIds, ["0","2"])
            XCTAssertEqual(updates.deletedModelIds, []) // We delete models, but then readd them before resuming listening again, so this should be empty.
        }

        XCTAssertFalse(consistencyManager.isPaused(pausedListener))
        pauseListeningForUpdates(pausedListener, consistencyManager: consistencyManager)
        XCTAssertTrue(consistencyManager.isPaused(pausedListener))

        let modelToDelete = TestRequiredModel(id: "3", data: 0)
        deleteModel(modelToDelete, consistencyManager: consistencyManager)
        updateWithNewModel(TestModel(id: "0", data: 0, children: [child, otherChild], requiredModel: TestRequiredModel(id: "1", data: -1)), consistencyManager: consistencyManager)
        updateWithNewModel(TestModel(id: "0", data: 0, children: [child, otherChild], requiredModel: TestRequiredModel(id: "1", data: 0)), consistencyManager: consistencyManager)
        updateWithNewModel(TestModel(id: "2", data: 6, children: [], requiredModel: TestRequiredModel(id: "3", data: -1)), consistencyManager: consistencyManager)
        updateWithNewModel(TestModel(id: "2", data: 6, children: [], requiredModel: TestRequiredModel(id: "3", data: 0)), consistencyManager: consistencyManager, context: "Last Change")

        // Resume listening for changes, and get all previous changes
        resumeListeningForUpdates(pausedListener, consistencyManager: consistencyManager)
        XCTAssertFalse(consistencyManager.isPaused(pausedListener))
        XCTAssertEqual(contextStringSavedToPausedListener, "Last Change")
        XCTAssertTrue(calledUpdateClosure)
    }

    /**
     We have two registered listeners. One listener pauses listening before a model is deleted.
     We confirm that before resuming listening, that listener still has that model.
     After resuming, it picks up the change accordingly.
     */
    func testDeleteDuringPausedState() {
        for testProjections in [true, false] {
            let model = TestModelGenerator.consistencyManagerModelWithTotalChildren(2, branchingFactor: 0, projectionModel: testProjections) { _ in
                return true
            }
            let consistencyManager = ConsistencyManager()
            let pausedListener = TestListener(model: model)
            let activeListener = TestListener(model: model)
            addListener(pausedListener, toConsistencyManager: consistencyManager)
            addListener(activeListener, toConsistencyManager: consistencyManager)

            var calledPausedListenerUpdateClosure = false
            var numberOfUpdatesforPausedListener = 0
            pausedListener.updateClosure = { _, updates in
                calledPausedListenerUpdateClosure = true
                XCTAssertEqual(updates.changedModelIds.count, 0)
                XCTAssertEqual(updates.deletedModelIds, ["0"])
                numberOfUpdatesforPausedListener += 1
                XCTAssertTrue(NSThread.currentThread().isMainThread)
            }
            var calledActiveListenerUpdateClosure = false
            var numberOfUpdatesForActiveListener = 0
            activeListener.updateClosure = { model, updates in
                calledActiveListenerUpdateClosure = true
                numberOfUpdatesForActiveListener += 1
                XCTAssertTrue(NSThread.currentThread().isMainThread)
            }

            // Current model before the delete
            var testModel = testModelFromListenerModel(pausedListener.model)!
            XCTAssertEqual(testModel.requiredModel.data, 0)
            testModel = testModelFromListenerModel(activeListener.model)!
            XCTAssertEqual(testModel.requiredModel.data, 0)

            XCTAssertFalse(consistencyManager.isPaused(pausedListener))
            pauseListeningForUpdates(pausedListener, consistencyManager: consistencyManager)
            XCTAssertTrue(consistencyManager.isPaused(pausedListener))
            updateWithNewModel(TestModel(id: "0", data: 1, children: [], requiredModel: TestRequiredModel(id: "1", data: 0)), consistencyManager: consistencyManager)
            deleteModel(testModel, consistencyManager: consistencyManager)

            // Delete has happened, but we didn't listen for it on the first listener.
            testModel = testModelFromListenerModel(pausedListener.model)!
            XCTAssertEqual(testModel.requiredModel.data, 0)
            XCTAssertFalse(calledPausedListenerUpdateClosure)
            // The second listener got the change.
            XCTAssertTrue(calledActiveListenerUpdateClosure)

            // Resume listening for changes, and get all previous changes.
            resumeListeningForUpdates(pausedListener, consistencyManager: consistencyManager)
            XCTAssertFalse(consistencyManager.isPaused(pausedListener))
            XCTAssertTrue(calledPausedListenerUpdateClosure)
            XCTAssertTrue(calledActiveListenerUpdateClosure)
            XCTAssertEqual(numberOfUpdatesforPausedListener, 1)
            XCTAssertEqual(numberOfUpdatesForActiveListener, 2)
        }
    }

    /**
     One listener has its model deleted, and then pauses and resumes listening.
     There should be no callbacks after the pausing/resuming happens.
     */
    func testDeleteWholeModelBeforePausingAndResuming() {
        let model = TestRequiredModel(id: "0", data: 0)

        let consistencyManager = ConsistencyManager()
        let listener = TestListener(model: model)

        var numberOfUpdates = 0
        listener.updateClosure = { (_, updates) in
            numberOfUpdates += 1
            XCTAssertEqual(updates.deletedModelIds, ["0"])
            XCTAssertTrue(NSThread.currentThread().isMainThread)
        }

        addListener(listener, toConsistencyManager: consistencyManager)
        deleteModel(model, consistencyManager: consistencyManager)

        XCTAssertEqual(numberOfUpdates, 1)

        XCTAssertFalse(consistencyManager.isPaused(listener))
        pauseListeningForUpdates(listener, consistencyManager: consistencyManager)
        XCTAssertTrue(consistencyManager.isPaused(listener))
        resumeListeningForUpdates(listener, consistencyManager: consistencyManager)
        XCTAssertFalse(consistencyManager.isPaused(listener))

        XCTAssertEqual(numberOfUpdates, 1)
        XCTAssertTrue(listener.model == nil)
    }

    /**
     If we update a submodel, then delete the whole tree, we shouldn't have anything in the updates.
     */
    func testUpdateThenDeleteWholeModel() {
        for testProjections in [true, false] {
            let modelToDelete = TestRequiredModel(id: "1", data: 0)
            let model = TestModelGenerator.consistencyManagerModelWithTotalChildren(4, branchingFactor: 1, projectionModel: testProjections) { _ in
                return true
            }

            let consistencyManager = ConsistencyManager()
            let listener = TestListener(model: model)

            var numberOfUpdates = 0
            listener.updateClosure = { (_, updates) in
                numberOfUpdates += 1
                XCTAssertEqual(updates.deletedModelIds, ["0", "1"])
                XCTAssertEqual(updates.changedModelIds, [])
                XCTAssertTrue(NSThread.currentThread().isMainThread)
            }

            addListener(listener, toConsistencyManager: consistencyManager)
            XCTAssertFalse(consistencyManager.isPaused(listener))
            pauseListeningForUpdates(listener, consistencyManager: consistencyManager)
            XCTAssertTrue(consistencyManager.isPaused(listener))

            let updateModel = TestModel(id: "2", data: 1, children: [], requiredModel: TestRequiredModel(id: nil, data: 0))
            updateWithNewModel(updateModel, consistencyManager: consistencyManager)
            deleteModel(modelToDelete, consistencyManager: consistencyManager)

            XCTAssertEqual(numberOfUpdates, 0)

            resumeListeningForUpdates(listener, consistencyManager: consistencyManager)
            XCTAssertFalse(consistencyManager.isPaused(listener))

            XCTAssertEqual(numberOfUpdates, 1)
            XCTAssertTrue(listener.model == nil)
        }
    }

    /**
     If we pause listening, edit the model locally, then resume listening, we should not get any updates from the consistency manager.
     */
    func testEditModelLocallyNoChanges() {
        let model = TestRequiredModel(id: "0", data: 0)

        let consistencyManager = ConsistencyManager()
        let listener = TestListener(model: model)

        listener.updateClosure = { _, _ in
            // This should never be called because we never get updated
            XCTFail()
        }

        addListener(listener, toConsistencyManager: consistencyManager)

        XCTAssertFalse(consistencyManager.isPaused(listener))
        pauseListeningForUpdates(listener, consistencyManager: consistencyManager)
        XCTAssertTrue(consistencyManager.isPaused(listener))

        let newModel = TestRequiredModel(id: "0", data: 1)
        listener.model = newModel
        // Don't wait for this to finish, we want to resume listening before this happens
        consistencyManager.updateWithNewModel(newModel)

        resumeListeningForUpdates(listener, consistencyManager: consistencyManager)
        XCTAssertFalse(consistencyManager.isPaused(listener))

        XCTAssertTrue(listener.model?.isEqualToModel(newModel) ?? false)
    }

    /**
     When we pause a listener and release it, it should actually get released.
     */
    func testReleaseListenerAfterPausing() {
        let model = TestRequiredModel(id: "0", data: 0)
        weak var listener: TestListener? = nil
        let consistencyManager = ConsistencyManager()

        autoreleasepool {
            let strongListener = TestListener(model: model)
            listener = strongListener

            addListener(strongListener, toConsistencyManager: consistencyManager)
            pauseListeningForUpdates(strongListener, consistencyManager: consistencyManager)
        }

        XCTAssertNil(listener)
    }

    /**
     PausedListenerItem structs with nil listeners should be removed from the stored list when cleanMemory is called for any reason.
     */
    func testCleanMemoryForPausedListeners() {
        let model = TestRequiredModel(id: "0", data: 0)
        let consistencyManager = ConsistencyManager()

        autoreleasepool {
            let strongListener: TestListener? = TestListener(model: model)
            addListener(strongListener!, toConsistencyManager: consistencyManager)
            pauseListeningForUpdates(strongListener!, consistencyManager: consistencyManager)
            XCTAssertEqual(consistencyManager.pausedListeners.count, 1)

        }

        XCTAssertEqual(consistencyManager.pausedListeners.count, 1)
        consistencyManager.cleanMemory()
        XCTAssertEqual(consistencyManager.pausedListeners.count, 0)
    }

    /// MARK: Tests with Pauses and BatchListeners

    /**
     One listener exists within a BatchListener.
     We pause the batch listener and then update the model.
     Only when we unpause should the BatchListener should get the update.
     */
    func testPausedBatchListenerWithOneInnerListener() {
        let testModel = TestModel(id: "0", data: 0, children: [], requiredModel: TestRequiredModel(id: "1", data: 0))

        let consistencyManager = ConsistencyManager()
        let individualListener = TestListener(model: testModel)
        let batchUpdateListener = BatchListener(listeners: [individualListener], consistencyManager: consistencyManager)
        let batchDelegate = TestBatchListenersDelegate()
        batchUpdateListener.delegate = batchDelegate
        pauseListeningForUpdates(batchUpdateListener, consistencyManager: consistencyManager)

        let updateModel = TestRequiredModel(id: "1", data: 3)

        var updates = 0
        batchDelegate.updateClosure = { _, _, _, _ in
            updates += 1
        }

        updateWithNewModel(updateModel, consistencyManager: consistencyManager, context: "context")
        XCTAssertEqual(updates, 0)

        resumeListeningForUpdates(batchUpdateListener, consistencyManager: consistencyManager)
        XCTAssertEqual(updates, 1)
    }

    /**
     Two listeners exists within a BatchListener.
     We pause the batch listener and then update models that affect both listeners.
     */
    func testPausedBatchListenerWithMultipleInnerListeners() {
        let consistencyManager = ConsistencyManager()
        let individualListener1 = TestListener(model: TestModel(id: "0", data: 0, children: [], requiredModel: TestRequiredModel(id: "1", data: 0)))
        let individualListener2 = TestListener(model: TestModel(id: "5", data: 0, children: [], requiredModel: TestRequiredModel(id: "1", data: 0)))
        let batchUpdateListener = BatchListener(listeners: [individualListener1, individualListener2], consistencyManager: consistencyManager)
        let batchDelegate = TestBatchListenersDelegate()
        batchUpdateListener.delegate = batchDelegate

        pauseListeningForUpdates(batchUpdateListener, consistencyManager: consistencyManager)

        let updateModel = TestRequiredModel(id: "1", data: 3)

        var updates = 0
        batchDelegate.updateClosure = { _, _, _, _ in
            updates += 1
        }

        updateWithNewModel(updateModel, consistencyManager: consistencyManager, context: "context")
        XCTAssertEqual(updates, 0)

        resumeListeningForUpdates(batchUpdateListener, consistencyManager: consistencyManager)
        XCTAssertEqual(updates, 1)
    }

    /**
     BatchListener is always listening.
     It contains one listener which pauses itself before an update.
     However, pausing a child listener should not affect a batch listener, since we ask that if you add
     a batch listener to a consistency manager that you do not also listen for updates on the child listener.
     */
    func testPausingListenerWithinBatchListener() {
        for testProjections in [true, false] {
            let testModel = TestModelGenerator.consistencyManagerModelWithTotalChildren(2, branchingFactor: 0, projectionModel: testProjections) { _ in
                return true
            }
            let consistencyManager = ConsistencyManager()
            let individualListener = TestListener(model: testModel)
            let batchUpdateListener = BatchListener(listeners: [individualListener], consistencyManager: consistencyManager)
            let batchDelegate = TestBatchListenersDelegate()
            batchUpdateListener.delegate = batchDelegate

            addListener(individualListener, toConsistencyManager: consistencyManager)
            pauseListeningForUpdates(individualListener, consistencyManager: consistencyManager)

            var updatesToBatch = 0
            batchDelegate.updateClosure = { _, _, _, _ in
                updatesToBatch += 1
            }

            var updatesToIndividual = 0
            individualListener.updateClosure = { _, _ in
                updatesToIndividual += 1
            }

            let updateModel = TestModel(id: "0", data: 4, children: [], requiredModel: TestRequiredModel(id: "1", data: 0))
            updateWithNewModel(updateModel, consistencyManager: consistencyManager, context: "context")
            XCTAssertEqual(updatesToBatch, 1)
            XCTAssertEqual(updatesToIndividual, 1)

            resumeListeningForUpdates(individualListener, consistencyManager: consistencyManager)
            XCTAssertEqual(updatesToBatch, 1)
            XCTAssertEqual(updatesToIndividual, 1)
        }
    }

    class TestBatchListenersDelegate: BatchListenerDelegate {

        var updateClosure: ((BatchListener, [ConsistencyManagerListener], ModelUpdates, Any?)->())?

        func batchListener(batchListener: BatchListener, hasUpdatedListeners listeners: [ConsistencyManagerListener], updates: ModelUpdates, context: Any?) {
            updateClosure?(batchListener, listeners, updates, context)
        }
    }
}