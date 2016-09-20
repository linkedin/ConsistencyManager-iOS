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
@testable import ConsistencyManager

/**
 This class defines a bunch of useful helper functions that are useful for writing tests for this library.
 Originally, these were helper methods, but it turns out that you should only use expectations from an XCTestCase subclass so this seemed like a good solution.
 */
class ConsistencyManagerTestCase: XCTestCase {

    /**
     This is a crazy work around for an Apple race condition introduced in iOS 10/Swift 2.3/Xcode 8 (unclear which).
     Basically, waitForExpectations sometimes takes the full time even if the expectation is fulfilled.
     This can cause the tests to take ~10 mins to run instead of 12 seconds.
     Even though it takes 10 mins to run tests, the tests do pass. So, this is only to speed up tests (it's ok if it doesn't work 100% of the time).
     This seems to fix the problem and tests now run quickly.
     As soon as this bug is fixed, we can remove this workaround.
     
     To test if the bug is fixed, comment out all this code and run tests. If they take the same amount of time, the bug has been fixed.
     */
    static var workaroundXCTestTimeoutTimer: DispatchSourceTimer?

    override func setUp() {
        super.setUp()
        if ConsistencyManagerTestCase.workaroundXCTestTimeoutTimer == nil {
            let timer = DispatchSource.makeTimerSource(queue: .main)
            ConsistencyManagerTestCase.workaroundXCTestTimeoutTimer = timer
            timer.setEventHandler {}
            let interval = DispatchTimeInterval.milliseconds(50)
            timer.scheduleRepeating(deadline: .now() + interval, interval: interval)
            timer.resume()
        }
    }

    func addListener(_ listener: ConsistencyManagerListener, toConsistencyManager consistencyManager: ConsistencyManager) {
        consistencyManager.addListener(listener)

        waitOnDispatchQueue(consistencyManager)
    }

    func removeListener(_ listener: ConsistencyManagerListener, fromConsistencyManager consistencyManager: ConsistencyManager) {
        consistencyManager.removeListener(listener)

        waitOnDispatchQueue(consistencyManager)
    }

    func updateNewModel(_ model: ConsistencyManagerModel, consistencyManager: ConsistencyManager, context: Any? = nil, timeout: TimeInterval = 10) {
        consistencyManager.updateModel(model, context: context)

        // First we need to wait for the consistency manager to finish on its queue
        waitOnDispatchQueue(consistencyManager, timeout: timeout)

        // Now, we need to wait for the main queue to do the actual updates
        flushMainQueueOperations()
    }

    /**
     This helper function is useful for testing projections.
     We want to validate the fields of our model, but aren't sure if it's a TestModel or ProjectionTestModel.
     This converts it to a TestModel and allows us to test the fields of the model.
     */
    func testModelFromListenerModel(_ model: ConsistencyManagerModel?) -> TestModel? {
        if let model = model as? TestModel {
            return model
        } else if let model = model as? ProjectionTestModel {
            return TestModel.testModelFromProjection(model)
        } else {
            XCTFail("Cannot convert listener model to test model.")
            return nil
        }
    }

    func deleteModel(_ model: ConsistencyManagerModel, consistencyManager: ConsistencyManager, context: Any? = nil) {
        consistencyManager.deleteModel(model, context: context)

        // First we need to wait for the consistency manager to finish on its queue
        waitOnDispatchQueue(consistencyManager)

        // Now, we need to wait for the main queue to do the actual updates
        flushMainQueueOperations()
    }

    func pauseListener(_ listener: ConsistencyManagerListener, consistencyManager: ConsistencyManager) {
        // This is synchronous so no wait is necessary here. This is just for readability and consistency with resume.
        consistencyManager.pauseListener(listener)
    }

    func resumeListener(_ listener: ConsistencyManagerListener, consistencyManager: ConsistencyManager) {
        consistencyManager.resumeListener(listener)

        // First we need to wait for the consistency manager to finish on its queue
        waitOnDispatchQueue(consistencyManager)

        // Now, we need to wait for the main queue to do the actual updates
        flushMainQueueOperations()
    }

    func waitOnDispatchQueue(_ consistencyManager: ConsistencyManager, timeout: TimeInterval = 10) {
        let expectation = self.expectation(description: "Wait for consistency manager to update internal state")

        let operation = BlockOperation() {
            expectation.fulfill()
        }
        consistencyManager.queue.addOperation(operation)

        waitForExpectations(timeout: timeout) { error in
            XCTAssertNil(error)
        }
    }

    func flushMainQueueOperations() {
        let expectation = self.expectation(description: "Wait for main queue to finish so the updates have happened")

        DispatchQueue.main.async {
            expectation.fulfill()
        }

        waitForExpectations(timeout: 10) { error in
            XCTAssertNil(error)
        }
    }

    func traverseModelTreeDFS(_ model: ConsistencyManagerModel, parent: String) {
        if let id = model.modelIdentifier {
            print("\(id), child of \(parent)")
            model.forEach() {
                child in self.traverseModelTreeDFS(child, parent: id)
            }
        }
    }
}
