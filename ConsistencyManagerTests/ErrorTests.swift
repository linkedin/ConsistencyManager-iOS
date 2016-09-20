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

class ErrorTests: ConsistencyManagerTestCase, ConsistencyManagerDelegate {

    var error: CriticalError?

    func testDeleteNoIDError() {
        let model = TestRequiredModel(id: nil, data: 0)

        let consistencyManager = ConsistencyManager()
        consistencyManager.delegate = self

        // This is an error. Should be a noop
        deleteModel(model, consistencyManager: consistencyManager)

        // Make sure the error got called
        if let error = error {
            XCTAssertEqual(error, CriticalError.DeleteIDFailure)
        } else {
            XCTFail()
        }
    }

    func testMapError() {
        let model = WrongMapModel()

        let consistencyManager = ConsistencyManager()
        consistencyManager.delegate = self

        let listener = TestListener(model: model)
        addListener(listener, toConsistencyManager: consistencyManager)

        updateNewModel(TestRequiredModel(id: "1", data: 1), consistencyManager: consistencyManager)

        // Make sure the error got called
        if let error = error {
            XCTAssertEqual(error, CriticalError.WrongMapClass)
        } else {
            XCTFail()
        }
    }
    
    // MARK: - Consistency Manager Delegate
    
    func consistencyManager(_ consistencyManager: ConsistencyManager, failedWithCriticalError error: String) {
        XCTAssertTrue(Thread.current.isMainThread)
        self.error = CriticalError(rawValue: error)
    }

    // MARK: - Error Classes

    class WrongMapModel: ConsistencyManagerModel {
        var modelIdentifier: String? {
            return "0"
        }

        func map(_ transform: (ConsistencyManagerModel) -> ConsistencyManagerModel?) -> ConsistencyManagerModel? {
            // This is an error
            return TestRequiredModel(id: nil, data: 0)
        }

        func forEach(_ function: (ConsistencyManagerModel) -> ()) {
            function(TestRequiredModel(id: "1", data: 0))
        }

        func isEqualToModel(_ other: ConsistencyManagerModel) -> Bool {
            return false
        }
    }
}
