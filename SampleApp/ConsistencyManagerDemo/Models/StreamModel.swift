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


final class StreamModel: ConsistencyManagerModel, Equatable {
    let id: String
    let updates: [UpdateModel]

    init(id: String, updates: [UpdateModel]) {
        self.id = id
        self.updates = updates
    }

    var modelIdentifier: String? {
        return id
    }

    func map(_ transform: (ConsistencyManagerModel) -> ConsistencyManagerModel?) -> ConsistencyManagerModel? {
        let newUpdates: [UpdateModel] = updates.flatMap { model in
            return transform(model) as? UpdateModel
        }
        return StreamModel(id: id, updates: newUpdates)
    }

    func forEach(_ function: (ConsistencyManagerModel) -> ()) {
        for model in updates {
            function(model)
        }
    }
}

func ==(lhs: StreamModel, rhs: StreamModel) -> Bool {
    return lhs.id == rhs.id && lhs.updates == rhs.updates
}
