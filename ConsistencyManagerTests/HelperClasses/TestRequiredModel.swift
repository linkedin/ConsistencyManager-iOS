// © 2016 LinkedIn Corp. All rights reserved.
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at  http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.

import Foundation
import ConsistencyManager

/**
 This model is intended for unit testing the consistency manager. It simply declares an id and some data.
 It is a child model of TestModel.
 */
final class TestRequiredModel: ConsistencyManagerModel, Equatable {
    let id: String?
    let data: Int

    init(id: String?, data: Int) {
        self.id = id
        self.data = data
    }

    var modelIdentifier: String? {
        return id
    }

    func map(_ transform: (ConsistencyManagerModel) -> ConsistencyManagerModel?) -> ConsistencyManagerModel? {
        return self
    }

    func forEach(_ function: (ConsistencyManagerModel) -> ()) {
        // Do nothing. No child models.
    }
}

func ==(lhs: TestRequiredModel, rhs: TestRequiredModel) -> Bool {
    return lhs.id == rhs.id && lhs.data == rhs.data
}

// MARK - CustomStringConvertible

extension TestRequiredModel: CustomStringConvertible {
    var description: String {
        return "\(id):\(data)"
    }
}
