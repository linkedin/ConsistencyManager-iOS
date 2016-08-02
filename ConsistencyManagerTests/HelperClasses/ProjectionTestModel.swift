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
 It is similar to TestModel but declares an extra field.
 Therefore, it also implements mergeModel which will merge TestModel into this model.
 */
final class ProjectionTestModel: ConsistencyManagerModel, Equatable {
    let id: String?
    let data: Int?
    let otherData: Int?
    let children: [ProjectionTestModel]
    let requiredModel: TestRequiredModel

    init(id: String?, data: Int?, otherData: Int?, children: [ProjectionTestModel], requiredModel: TestRequiredModel) {
        self.id = id
        self.data = data
        self.otherData = otherData
        self.children = children
        self.requiredModel = requiredModel
    }

    var modelIdentifier: String? {
        return id
    }

    func map(transform: ConsistencyManagerModel -> ConsistencyManagerModel?) -> ConsistencyManagerModel? {
        var newChildren: [ProjectionTestModel] = []
        for model in children {
            if let newModel = transform(model) as? ProjectionTestModel {
                newChildren.append(newModel)
            }
        }

        if let newRequiredModel = transform(requiredModel) as? TestRequiredModel {
            return ProjectionTestModel(id: id, data: data, otherData: otherData, children: newChildren, requiredModel: newRequiredModel)
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
        if let model = model as? ProjectionTestModel {
            return model
        } else if let model = model as? TestModel {
            return testModelFromProjection(model)
        } else {
            assertionFailure("Tried to merge two models which cannot be merged: \(self.dynamicType) and \(model.dynamicType)")
            // The best we can do is return self (no merging done)
            return self
        }
    }

    private func testModelFromProjection(model: TestModel) -> ProjectionTestModel {
        let newChildren = model.children.map { currentChild in
            return testModelFromProjection(currentChild)
        }
        // For otherData, we're going to use our current value. For everything else, we're going to use the other model's values.
        return ProjectionTestModel(id: model.id, data: model.data, otherData: otherData, children: newChildren, requiredModel: model.requiredModel)
    }
}

// MARK - Equatable

func ==(lhs: ProjectionTestModel, rhs: ProjectionTestModel) -> Bool {
    return lhs.id == rhs.id
        && lhs.data == rhs.data
        && lhs.otherData == rhs.otherData
        && lhs.children == rhs.children
        && lhs.requiredModel == rhs.requiredModel
}

// MARK - CustomStringConvertible

extension ProjectionTestModel: CustomStringConvertible {
    var description: String {
        return "\(id):\(data):\(otherData)-\(requiredModel)-\(children)"
    }
}

// MARK - Helpers

extension ProjectionTestModel {
    func recursiveChildWithId(id: String) -> ProjectionTestModel? {
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
