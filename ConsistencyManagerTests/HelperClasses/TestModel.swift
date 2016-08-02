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
This model is intended for unit testing the consistency manager. It simply declares some child objects and some data.
*/
final class TestModel: ConsistencyManagerModel, Equatable {
    let id: String?
    let data: Int?
    let children: [TestModel]
    let requiredModel: TestRequiredModel

    init(id: String?, data: Int?, children: [TestModel], requiredModel: TestRequiredModel) {
        self.id = id
        self.data = data
        self.children = children
        self.requiredModel = requiredModel
    }

    var modelIdentifier: String? {
        return id
    }

    func map(transform: ConsistencyManagerModel -> ConsistencyManagerModel?) -> ConsistencyManagerModel? {
        var newChildren: [TestModel] = []
        for model in children {
            if let newModel = transform(model) as? TestModel {
                newChildren.append(newModel)
            }
        }

        if let newRequiredModel = transform(requiredModel) as? TestRequiredModel {
            return TestModel(id: id, data: data, children: newChildren, requiredModel: newRequiredModel)
        } else {
            return nil
        }
    }

    func forEach(function: ConsistencyManagerModel -> ()) {
        for model in children {
            function(model)
        }
        function(requiredModel)
    }

    func mergeModel(model: ConsistencyManagerModel) -> ConsistencyManagerModel {
        if let model = model as? TestModel {
            return model
        } else if let model = model as? ProjectionTestModel {
            return TestModel.testModelFromProjection(model)
        } else {
            assertionFailure("Tried to merge two models which cannot be merged: \(self.dynamicType) and \(model.dynamicType)")
            // The best we can do is return self (no merging done)
            return self
        }
    }

    static func testModelFromProjection(model: ProjectionTestModel) -> TestModel {
        let children = model.children.map { currentChild in
            return testModelFromProjection(currentChild)
        }
        return TestModel(id: model.id, data: model.data, children: children, requiredModel: model.requiredModel)
    }
}

// MARK - Equatable

func ==(lhs: TestModel, rhs: TestModel) -> Bool {
    return lhs.id == rhs.id
        && lhs.data == rhs.data
        && lhs.children == rhs.children
        && lhs.requiredModel == rhs.requiredModel
}

// MARK - CustomStringConvertible

extension TestModel: CustomStringConvertible {
    var description: String {
        return "\(id):\(data)-\(requiredModel)-\(children)"
    }
}

// MARK - Helpers

extension TestModel {
    func recursiveChildWithId(id: String) -> TestModel? {
        if let currentId = self.id {
            if currentId == id {
                return self
            }
        }
        for child in children {
            let foundModel = child.recursiveChildWithId(id)
            if let foundModel = foundModel {
                return foundModel
            }
        }
        
        // We didn't find anything
        return nil
    }
}
