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

class RemoveListenerTests: ConsistencyManagerTestCase {

    func testRemoveListener() {
        let testModel = TestRequiredModel(id: "0", data: 0)

        let consistencyManager = ConsistencyManager()
        let listener = TestListener(model: testModel)

        addListener(listener, toConsistencyManager: consistencyManager)

        let zeroListener = consistencyManager.listeners["0"]?[0]
        if let zeroListener = zeroListener {
            XCTAssertTrue(zeroListener === listener)
        } else {
            XCTFail()
        }

        removeListener(listener, fromConsistencyManager: consistencyManager)

        let listeners = consistencyManager.listeners["0"]
        if let listeners = listeners {
            XCTAssertEqual(listeners.count, 0)
        } else {
            // Success
        }
    }

    func testRemoveUpdatesListener() {
        let consistencyManager = ConsistencyManager()
        let listener = TestUpdatesListener()

        addUpdatesListener(listener, toConsistencyManager: consistencyManager)

        let zeroListener = consistencyManager.modelUpdatesListeners[0]
        if let zeroListener = zeroListener {
            XCTAssertTrue(zeroListener === listener)
        } else {
            XCTFail()
        }

        removeUpdatesListener(listener, fromConsistencyManager: consistencyManager)

        XCTAssertEqual(consistencyManager.modelUpdatesListeners.count, 0)
    }
}
