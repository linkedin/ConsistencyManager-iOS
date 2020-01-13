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

class ModelUpdatesListenerTests: ConsistencyManagerTestCase {
    
    func testSingleListener() {
        let requiredModel = TestRequiredModel(id: "1", data: 0)
        let testModel = TestModel(id: "0", data: 0, children: [], requiredModel: requiredModel)

        let consistencyManager = ConsistencyManager()
        let listener = TestUpdatesListener()

        addUpdatesListener(listener, toConsistencyManager: consistencyManager)

        var calledUpdateClosure = 0
        listener.updateClosure = { model, children, context in
            calledUpdateClosure += 1
            XCTAssertEqual(model as? TestModel, testModel)
            XCTAssertEqual(children.count, 2)
            XCTAssertEqual(children["0"]?.models[0] as? TestModel, testModel)
            XCTAssertEqual(children["1"]?.models[0] as? TestRequiredModel, requiredModel)
            XCTAssertEqual(context as? String, "context")
        }

        updateNewModel(testModel, consistencyManager: consistencyManager, context: "context")

        XCTAssertEqual(calledUpdateClosure, 1)
    }

    func testMultipleListeners() {
        let requiredModel = TestRequiredModel(id: "1", data: 0)
        let testModel = TestModel(id: "0", data: 0, children: [], requiredModel: requiredModel)

        let consistencyManager = ConsistencyManager()
        let listener = TestUpdatesListener()
        let listener2 = TestUpdatesListener()

        addUpdatesListener(listener, toConsistencyManager: consistencyManager)
        addUpdatesListener(listener2, toConsistencyManager: consistencyManager)

        var calledUpdateClosure = 0
        listener.updateClosure = { model, children, context in
            calledUpdateClosure += 1
            XCTAssertEqual(model as? TestModel, testModel)
            XCTAssertEqual(children.count, 2)
            XCTAssertEqual(children["0"]?.models[0] as? TestModel, testModel)
            XCTAssertEqual(children["1"]?.models[0] as? TestRequiredModel, requiredModel)
            XCTAssertEqual(context as? String, "context")
        }

        var calledUpdate2Closure = 0
        listener2.updateClosure = { model, children, context in
            calledUpdate2Closure += 1
            XCTAssertEqual(model as? TestModel, testModel)
            XCTAssertEqual(children.count, 2)
            XCTAssertEqual(children["0"]?.models[0] as? TestModel, testModel)
            XCTAssertEqual(children["1"]?.models[0] as? TestRequiredModel, requiredModel)
            XCTAssertEqual(context as? String, "context")
        }

        updateNewModel(testModel, consistencyManager: consistencyManager, context: "context")

        XCTAssertEqual(calledUpdateClosure, 1)
        XCTAssertEqual(calledUpdate2Closure, 1)
    }

    func testDelete() {
        let requiredModel = TestRequiredModel(id: "1", data: 0)
        let testModel = TestModel(id: "0", data: 0, children: [], requiredModel: requiredModel)

        let consistencyManager = ConsistencyManager()
        let listener = TestUpdatesListener()

        addUpdatesListener(listener, toConsistencyManager: consistencyManager)

        var calledUpdateClosure = 0
        listener.updateClosure = { model, children, context in
            calledUpdateClosure += 1
            XCTAssertEqual(model as? TestModel, testModel)
            XCTAssertEqual(children.count, 1)
            XCTAssertEqual(children["0"], ModelChange.deleted)
            XCTAssertEqual(context as? String, "context")
        }

        deleteModel(testModel, consistencyManager: consistencyManager, context: "context")

        XCTAssertEqual(calledUpdateClosure, 1)
    }

    func testRetainCycle() {
        weak var listener: TestUpdatesListener? = nil
        let consistencyManager = ConsistencyManager()

        autoreleasepool {
            let strongListener = TestUpdatesListener()
            listener = strongListener

            addUpdatesListener(strongListener, toConsistencyManager: consistencyManager)
            flushMainQueueOperations()
        }

        wait(for: listener == nil, timeout: 3, description: "Listener is deallocated")

        // Shouldn't be listening anymore
        let listeners = consistencyManager.modelUpdatesListeners.prune()
        XCTAssertEqual(listeners.count, 0)
    }
}
