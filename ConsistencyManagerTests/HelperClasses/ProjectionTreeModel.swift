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
 This model is intended for unit testing the consistency manager.
 It's an interesting class which could be one of three projections. I decided to use one class to test projections so:
 - We could test overriding projection identifier.
 - I wouldn't need to write 3 different classes.
 
 This class has `data`, `otherData` and two optional children.
 It has a projection of data, otherData or both. If it's the data projection, then otherData is nil and should be ignored.
 */
final class ProjectionTreeModel: ConsistencyManagerModel, Equatable {
    let id: Int
    let data: Int?
    let otherData: Int?
    let child: ProjectionTreeModel?
    let otherChild: ProjectionTreeModel?
    let type: Type

    /**
     We're going to use one class which represents three projections.
     One projection will have both data and otherData
     The other's will just have one of these fields.
     */
    enum Type: String {
        case data
        case otherData
        case both
    }

    init(type: Type, id: Int, data: Int?, otherData: Int?, child: ProjectionTreeModel?, otherChild: ProjectionTreeModel?) {
        self.type = type
        self.id = id
        self.data = data
        self.otherData = otherData
        self.child = child
        self.otherChild = otherChild
    }

    var modelIdentifier: String? {
        return "\(id)"
    }

    func map(transform: ConsistencyManagerModel -> ConsistencyManagerModel?) -> ConsistencyManagerModel? {
        let newChild = child.flatMap(transform) as? ProjectionTreeModel
        let newOtherChild = otherChild.flatMap(transform) as? ProjectionTreeModel
        return ProjectionTreeModel(type: type, id: id, data: data, otherData: otherData, child: newChild, otherChild: newOtherChild)
    }

    func forEach(function: ConsistencyManagerModel -> ()) {
        if let child = child {
            function(child)
        }
        if let otherChild = otherChild {
            function(otherChild)
        }
    }

    func mergeModel(model: ConsistencyManagerModel) -> ConsistencyManagerModel {
        if let model = model as? ProjectionTreeModel {
            return projectionTreeModelFromMergeModel(model)
        } else {
            assertionFailure("Cannot merge this model.")
            return self
        }
    }

    var projectionIdentifier: String {
        return type.rawValue
    }

    private func projectionTreeModelFromMergeModel(model: ProjectionTreeModel) -> ProjectionTreeModel {
        // We only want to update fields that are on our projection
        // If we are of type .data we don't want to grab the otherData field
        var otherData = self.otherData
        var data = self.data
        // This is a little complex. We only want to update a field if both models care about that field.
        switch type {
        case .data:
            if model.type == .both || model.type == .data {
                data = model.data
            }
        case .otherData:
            if model.type == .both || model.type == .otherData {
                otherData = model.otherData
            }
        case .both:
            if model.type == .both || model.type == .data {
                data = model.data
            }
            if model.type == .both || model.type == .otherData {
                otherData = model.otherData
            }
        }
        let child = self.child?.projectionTreeModelFromMergeModel(model.child)
        let otherChild = self.otherChild?.projectionTreeModelFromMergeModel(model.otherChild)
        return ProjectionTreeModel(type: type, id: id, data: data, otherData: otherData, child: child, otherChild: otherChild)
    }

    private func projectionTreeModelFromMergeModel(model: ProjectionTreeModel?) -> ProjectionTreeModel? {
        guard let model = model else {
            return nil
        }
        return projectionTreeModelFromMergeModel(model)
    }
}

func ==(lhs: ProjectionTreeModel, rhs: ProjectionTreeModel) -> Bool {
    return lhs.id == rhs.id &&
        lhs.data == rhs.data &&
        lhs.otherData == rhs.otherData &&
        lhs.child == rhs.child &&
        lhs.otherChild == rhs.otherChild &&
        lhs.type == rhs.type
}

// MARK - CustomStringConvertible

extension ProjectionTreeModel: CustomStringConvertible {
    var description: String {
        return "\(id):\(data):\(otherData)|\(child)|\(otherChild)"
    }
}

