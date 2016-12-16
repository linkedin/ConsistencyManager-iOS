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

class ModelChangeTests: ConsistencyManagerTestCase {
    
    func testDeleteEquality() {
        XCTAssertEqual(ModelChange.deleted, ModelChange.deleted)
        XCTAssertNotEqual(ModelChange.deleted, ModelChange.updated([]))
    }

    func testUpdatedEquality() {
        let model = TestModel(id: "0", data: nil, children: [], requiredModel: TestRequiredModel(id: nil, data: 0))
        let otherModel = TestModel(id: "1", data: nil, children: [], requiredModel: TestRequiredModel(id: nil, data: 0))

        XCTAssertEqual(ModelChange.updated([model]), ModelChange.updated([model]))
        XCTAssertNotEqual(ModelChange.updated([model]), ModelChange.updated([otherModel]))
        XCTAssertNotEqual(ModelChange.updated([model]), ModelChange.updated([model, model]))
        XCTAssertNotEqual(ModelChange.updated([model]), ModelChange.deleted)
    }
}
