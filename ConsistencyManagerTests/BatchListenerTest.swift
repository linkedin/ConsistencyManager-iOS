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

class BatchListenerTest: ConsistencyManagerTestCase {

    func testSingleListener() {
        let testModel = TestModel(id: "0", data: 0, children: [], requiredModel: TestRequiredModel(id: "1", data: 0))

        let consistencyManager = ConsistencyManager()
        let listener = TestListener(model: testModel)
        let batchUpdateListener = BatchListener(listeners: [listener], consistencyManager: consistencyManager)
        let batchDelegate = TestBatchListenersDelegate()
        batchUpdateListener.delegate = batchDelegate

        let updateModel = TestRequiredModel(id: "1", data: 3)

        var calledUpdateClosure = 0
        batchDelegate.updateClosure = { batchListener, listeners, updates, context in
            calledUpdateClosure += 1
            XCTAssertTrue(batchListener === batchUpdateListener)
            XCTAssertEqual(listeners.count, 1)
            XCTAssertTrue(listeners[0] === listener)
            XCTAssertEqual((listener.model as? TestModel)?.requiredModel.data, 3)
            XCTAssertEqual(updates.changedModelIds.count, 2)
            XCTAssertEqual(updates.deletedModelIds.count, 0)
            XCTAssertTrue(updates.changedModelIds.contains("0"))
            XCTAssertTrue(updates.changedModelIds.contains("1"))
            XCTAssertEqual(context as? String, "context")
        }

        var calledListenerUpdateClosure = 0
        listener.updateClosure = { _, updates in
            calledListenerUpdateClosure += 1
            XCTAssertEqual(updates.changedModelIds.count, 2)
            XCTAssertEqual(updates.deletedModelIds.count, 0)
            XCTAssertTrue(updates.changedModelIds.contains("0"))
            XCTAssertTrue(updates.changedModelIds.contains("1"))
        }
        listener.contextClosure = { context in
            XCTAssertEqual(context as? String, "context")
        }

        updateWithNewModel(updateModel, consistencyManager: consistencyManager, context: "context")

        XCTAssertEqual(calledUpdateClosure, 1)
        XCTAssertEqual(calledListenerUpdateClosure, 1)
    }

    func testTwoListenersOneAffected() {
        let testModel = TestModel(id: "0", data: 0, children: [], requiredModel: TestRequiredModel(id: "1", data: 0))
        let testModel2 = TestModel(id: "2", data: 0, children: [], requiredModel: TestRequiredModel(id: "3", data: 0))

        let consistencyManager = ConsistencyManager()
        let listener = TestListener(model: testModel)
        let listener2 = TestListener(model: testModel2)
        let batchUpdateListener = BatchListener(listeners: [listener, listener2], consistencyManager: consistencyManager)
        let batchDelegate = TestBatchListenersDelegate()
        batchUpdateListener.delegate = batchDelegate

        let updateModel = TestRequiredModel(id: "1", data: 3)

        var calledUpdateClosure = 0
        batchDelegate.updateClosure = { batchListener, listeners, updates, context in
            calledUpdateClosure += 1
            XCTAssertTrue(batchListener === batchUpdateListener)
            XCTAssertEqual(listeners.count, 1)
            XCTAssertTrue(listeners[0] === listener)
            XCTAssertEqual((listener.model as? TestModel)?.requiredModel.data, 3)
            XCTAssertEqual(updates.changedModelIds, ["0", "1"])
            XCTAssertEqual(updates.deletedModelIds.count, 0)
            XCTAssertEqual(context as? String, "context")

            // Listener 2 shouldn't have changed
            XCTAssertEqual(listener2.model as? TestModel, testModel2)
        }

        var calledListenerUpdateClosure = 0
        listener.updateClosure = { _, updates in
            calledListenerUpdateClosure += 1
            XCTAssertEqual(updates.changedModelIds, ["0", "1"])
            XCTAssertEqual(updates.deletedModelIds.count, 0)
        }
        listener.contextClosure = { context in
            XCTAssertEqual(context as? String, "context")
        }

        listener2.updateClosure = { _, _ in
            XCTFail()
        }

        updateWithNewModel(updateModel, consistencyManager: consistencyManager, context: "context")

        XCTAssertEqual(calledUpdateClosure, 1)
        XCTAssertEqual(calledListenerUpdateClosure, 1)
    }

    func testTwoListenersBothAffected() {
        let testModel = TestModel(id: "0", data: 0, children: [], requiredModel: TestRequiredModel(id: "1", data: 0))
        let testModel2 = TestModel(id: "2", data: 0, children: [], requiredModel: TestRequiredModel(id: "1", data: 0))

        let consistencyManager = ConsistencyManager()
        let listener = TestListener(model: testModel)
        let listener2 = TestListener(model: testModel2)
        let batchUpdateListener = BatchListener(listeners: [listener, listener2], consistencyManager: consistencyManager)
        let batchDelegate = TestBatchListenersDelegate()
        batchUpdateListener.delegate = batchDelegate

        let updateModel = TestRequiredModel(id: "1", data: 3)

        var calledUpdateClosure = 0
        batchDelegate.updateClosure = { batchListener, listeners, updates, context in
            calledUpdateClosure += 1
            XCTAssertTrue(batchListener === batchUpdateListener)
            XCTAssertEqual(listeners.count, 2)
            XCTAssertTrue(listeners[0] === listener)
            XCTAssertTrue(listeners[1] === listener2)
            XCTAssertEqual((listener.model as? TestModel)?.requiredModel.data, 3)
            XCTAssertEqual((listener2.model as? TestModel)?.requiredModel.data, 3)
            XCTAssertEqual(updates.changedModelIds.count, 3)
            XCTAssertEqual(updates.deletedModelIds.count, 0)
            XCTAssertTrue(updates.changedModelIds.contains("0"))
            XCTAssertTrue(updates.changedModelIds.contains("1"))
            XCTAssertTrue(updates.changedModelIds.contains("2"))
            XCTAssertEqual(context as? String, "context")

        }

        var calledListenerUpdateClosure = 0
        listener.updateClosure = { _, updates in
            calledListenerUpdateClosure += 1
            XCTAssertEqual(updates.changedModelIds.count, 2)
            XCTAssertEqual(updates.deletedModelIds.count, 0)
            XCTAssertTrue(updates.changedModelIds.contains("0"))
            XCTAssertTrue(updates.changedModelIds.contains("1"))
        }
        listener.contextClosure = { context in
            XCTAssertEqual(context as? String, "context")
        }

        var calledListener2UpdateClosure = 0
        listener2.updateClosure = { _, updates in
            calledListener2UpdateClosure += 1
            XCTAssertEqual(updates.changedModelIds.count, 2)
            XCTAssertEqual(updates.deletedModelIds.count, 0)
            XCTAssertTrue(updates.changedModelIds.contains("2"))
            XCTAssertTrue(updates.changedModelIds.contains("1"))
        }

        updateWithNewModel(updateModel, consistencyManager: consistencyManager, context: "context")

        XCTAssertEqual(calledUpdateClosure, 1)
        XCTAssertEqual(calledListenerUpdateClosure, 1)
        XCTAssertEqual(calledListener2UpdateClosure, 1)
    }

    func testMultipleListenersMultipleDeletes() {
        let childModel = TestModel(id: "3", data: 0, children: [], requiredModel: TestRequiredModel(id: "4", data: 0))
        let testModel = TestModel(id: "0", data: 0, children: [childModel], requiredModel: TestRequiredModel(id: "1", data: 0))
        let testModel2 = TestModel(id: "2", data: 0, children: [childModel], requiredModel: TestRequiredModel(id: "1", data: 0))

        let consistencyManager = ConsistencyManager()
        let listener = TestListener(model: testModel)
        let listener2 = TestListener(model: testModel2)
        let batchUpdateListener = BatchListener(listeners: [listener, listener2], consistencyManager: consistencyManager)
        let batchDelegate = TestBatchListenersDelegate()
        batchUpdateListener.delegate = batchDelegate

        let updateModel = TestRequiredModel(id: "4", data: 0)

        var calledUpdateClosure = 0
        batchDelegate.updateClosure = { batchListener, listeners, updates, context in
            calledUpdateClosure += 1
            XCTAssertTrue(batchListener === batchUpdateListener)
            XCTAssertEqual(listeners.count, 2)
            XCTAssertTrue(listeners[0] === listener)
            XCTAssertTrue(listeners[1] === listener2)
            XCTAssertEqual((listener.model as? TestModel)?.children.count, 0)
            XCTAssertEqual((listener2.model as? TestModel)?.children.count, 0)
            XCTAssertEqual(updates.changedModelIds.count, 2)
            XCTAssertEqual(updates.deletedModelIds.count, 2)
            XCTAssertTrue(updates.changedModelIds.contains("0"))
            XCTAssertTrue(updates.changedModelIds.contains("2"))
            XCTAssertTrue(updates.deletedModelIds.contains("3"))
            XCTAssertTrue(updates.deletedModelIds.contains("4"))
            XCTAssertEqual(context as? String, "context")

        }

        var calledListenerUpdateClosure = 0
        listener.updateClosure = { _, updates in
            calledListenerUpdateClosure += 1
            XCTAssertEqual(updates.changedModelIds.count, 1)
            XCTAssertTrue(updates.changedModelIds.contains("0"))
            XCTAssertEqual(updates.deletedModelIds.count, 2)
            XCTAssertTrue(updates.deletedModelIds.contains("3"))
            XCTAssertTrue(updates.deletedModelIds.contains("4"))
        }
        listener.contextClosure = { context in
            XCTAssertEqual(context as? String, "context")
        }

        var calledListener2UpdateClosure = 0
        listener2.updateClosure = { _, updates in
            calledListener2UpdateClosure += 1
            XCTAssertEqual(updates.changedModelIds.count, 1)
            XCTAssertTrue(updates.changedModelIds.contains("2"))
            XCTAssertEqual(updates.deletedModelIds.count, 2)
            XCTAssertTrue(updates.deletedModelIds.contains("3"))
            XCTAssertTrue(updates.deletedModelIds.contains("4"))
        }

        deleteModel(updateModel, consistencyManager: consistencyManager, context: "context")

        XCTAssertEqual(calledUpdateClosure, 1)
        XCTAssertEqual(calledListenerUpdateClosure, 1)
        XCTAssertEqual(calledListener2UpdateClosure, 1)
    }

    class TestBatchListenersDelegate: BatchListenerDelegate {

        var updateClosure: ((BatchListener, [ConsistencyManagerListener], ModelUpdates, Any?)->())?

        func batchListener(batchListener: BatchListener, hasUpdatedListeners listeners: [ConsistencyManagerListener], updates: ModelUpdates, context: Any?) {
            updateClosure?(batchListener, listeners, updates, context)
        }
    }
}
