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

class MemoryWarningTests: ConsistencyManagerTestCase {

    var cleanMemoryStartedTimes = [NSDate]()
    var cleanMemoryFinishedTimes = [NSDate]()


    func testMemoryWarning() {
        let testStart = NSDate()

        NSNotificationCenter.defaultCenter().addObserverForName(ConsistencyManager.kCleanMemoryAsynchronousWorkStarted, object: nil, queue: nil) { _ in
            self.cleanMemoryStartedTimes.append(NSDate())
        }

        NSNotificationCenter.defaultCenter().addObserverForName(ConsistencyManager.kCleanMemoryAsynchronousWorkFinished, object: nil, queue: nil) { _ in
            self.cleanMemoryFinishedTimes.append(NSDate())
        }

        let model = TestRequiredModel(id: "0", data: 0)

        // Setting this up with a block ensures that the listener will be released and is out of scope.
        let consistencyManager: ConsistencyManager = {
            let consistencyManager = ConsistencyManager()
            let listener = TestListener(model: model)

            addListener(listener, toConsistencyManager: consistencyManager)

            return consistencyManager
            }()

        // This part MAY fail in the future if we change the logic for when we prune the listeners dictionary
        // If this starts to fail, we should write this test to prove that memory warnings are doing something
        if let listenersArray = consistencyManager.listeners["0"] {
            XCTAssertEqual(listenersArray.count, 1)
        } else {
            XCTFail()
        }

        NSNotificationCenter.defaultCenter().postNotificationName(UIApplicationDidReceiveMemoryWarningNotification, object: nil)
        waitOnDispatchQueue(consistencyManager)

        // Now, listeners array should be 0 or nil
        if let listenersArray = consistencyManager.listeners["0"] {
            XCTAssertEqual(listenersArray.count, 0)
        }
        // Else it's nil which is fine too

        // Now, let's check we got the right start/finish times
        XCTAssertEqual(cleanMemoryStartedTimes.count, 1)
        XCTAssertEqual(cleanMemoryFinishedTimes.count, 1)
        XCTAssertTrue(cleanMemoryStartedTimes[0].timeIntervalSince1970 <= cleanMemoryFinishedTimes[0].timeIntervalSince1970)
        XCTAssertTrue(testStart.timeIntervalSince1970 <= cleanMemoryStartedTimes[0].timeIntervalSince1970)
    }
}
