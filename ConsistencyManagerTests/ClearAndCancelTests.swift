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

class ClearAndCancelTests: ConsistencyManagerTestCase {
    
    func testListenerClear() {
        let testModel = TestRequiredModel(id: "0", data: 0)

        let consistencyManager = ConsistencyManager()
        let listener = TestListener(model: testModel)
        let pausedListener = TestListener(model: testModel)

        addListener(listener, toConsistencyManager: consistencyManager)
        addListener(pausedListener, toConsistencyManager: consistencyManager)
        consistencyManager.pauseListeningForUpdates(pausedListener)

        let expectation = expectationWithDescription("Wait for clear to complete")
        consistencyManager.clearListenersAndCancelAllTasks {
            expectation.fulfill()
        }

        waitForExpectationsWithTimeout(10, handler: nil)

        XCTAssertEqual(consistencyManager.listeners.count, 0)
        XCTAssertEqual(consistencyManager.pausedListeners.count, 0)
    }

    func testUpdateCancel() {
        let testModel = TestRequiredModel(id: "0", data: 0)

        let consistencyManager = ConsistencyManager()
        let listener = TestListener(model: testModel)

        addListener(listener, toConsistencyManager: consistencyManager)

        listener.updateClosure = { _, _ in
            XCTFail()
        }

        let updateModel = TestRequiredModel(id: "0", data: 1)
        consistencyManager.updateWithNewModel(updateModel)

        let expectation = expectationWithDescription("Wait for clear to complete")
        consistencyManager.clearListenersAndCancelAllTasks {
            expectation.fulfill()
        }

        waitForExpectationsWithTimeout(10, handler: nil)

        waitOnDispatchQueue(consistencyManager)
        waitOnMainThread()

        // Test succeeds as long as XCTFail() never gets called.
    }

    /**
     This test tries cancelling all the blocks while a task is half way complete.
     The task should still not go through.
     */
    func testUpdateCancelWhileTaskRunning() {
        let testModel = TestRequiredModel(id: "0", data: 0)

        let consistencyManager = ConsistencyManager()
        let listener = TestListener(model: testModel)

        addListener(listener, toConsistencyManager: consistencyManager)

        listener.updateClosure = { _, _ in
            XCTFail()
        }

        let expectation = expectationWithDescription("Wait for clear to complete")
        listener.currentModelRequested = {
            // We're half way through this task. So let's cancel everything!
            consistencyManager.clearListenersAndCancelAllTasks {
                expectation.fulfill()
            }
        }

        let updateModel = TestRequiredModel(id: "0", data: 1)
        consistencyManager.updateWithNewModel(updateModel)

        waitForExpectationsWithTimeout(10, handler: nil)

        waitOnDispatchQueue(consistencyManager)
        waitOnMainThread()

        // Test succeeds as long as XCTFail() never gets called.
    }
}
