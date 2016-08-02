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
This class generates test models for use in the unit tests. It can create models with a variety of sizes and depths.
*/

class TestModelGenerator {

    /**
     One of the main generator methods for the class.
     This generator allows you to return either a TestModel or ProjectionTestModel so you can run your tests easily on both.

     It generates a tree of TestModels for use for unit tests. This tree will have a certain number of children, and the size of the children array in TestModel will be the branching factor. The ids are zero indexed and are also used as data on each model.

     The TestModels will all have odd ids. The TestRequiredModels will all have even ids.

     - parameter children: Total number of children to be used in the model. This will be equal to the maxId + 1. This must be even since the id of a required model is always testModelId + 1
     - parameter branchingFactor: number of children in the children array of each model
     - parameter projectionModel: If false, it will return a `TestModel`. If true, it will return a `ProjectionTestModel`.
     This allows us to easily write our tests so we test both projections and regular models.
     - parameter includeId: closure which dictates if you want an id on a certain model. Recommend that you don't make this % 2 since that will just make all the required models not have ids
     */
    class func consistencyManagerModelWithTotalChildren(children: Int, branchingFactor: Int, projectionModel: Bool, startingId: Int = 0, includeId: Int -> Bool) -> ConsistencyManagerModel {
        assert(children % 2 == 0, "If you don't have an even number of children, you will have unexpected ids")
        // Each node in the tree actually represents two models (TestModel and TestRequiredModel)
        let tree = childrenTreeWithTotalNodes(children / 2, branchingFactor: branchingFactor, startingId: startingId)
        if projectionModel {
            return projectionTestModelFromTree(tree, includeId: includeId)
        } else {
            return testModelFromTree(tree, includeId: includeId)
        }
    }

    /**
     One of the main generator methods for the class.

     It generates a tree of TestModels for use for unit tests. This tree will have a certain number of children, and the size of the children array in TestModel will be the branching factor. The ids are zero indexed and are also used as data on each model.

     The TestModels will all have odd ids. The TestRequiredModels will all have even ids.

     - parameter children: Total number of children to be used in the model. This will be equal to the maxId + 1. This must be even since the id of a required model is always testModelId + 1
     - parameter branchingFactor: number of children in the children array of each model
     - parameter includeId: closure which dictates if you want an id on a certain model. Recommend that you don't make this % 2 since that will just make all the required models not have ids
     */
    class func testModelWithTotalChildren(children: Int, branchingFactor: Int, startingId: Int = 0, includeId: Int -> Bool) -> TestModel {
        assert(children % 2 == 0, "If you don't have an even number of children, you will have unexpected ids")
        // Each node in the tree actually represents two models (TestModel and TestRequiredModel)
        let tree = childrenTreeWithTotalNodes(children / 2, branchingFactor: branchingFactor, startingId: startingId)
        return testModelFromTree(tree, includeId: includeId)
    }

    /**
    Generates an immutable TestModel from a tree object.
    */
    private class func testModelFromTree(tree: ChildrenTree, includeId: Int -> Bool) -> TestModel {
        let testModelChildren: [TestModel] = tree.children.map { node in
            return self.testModelFromTree(node, includeId: includeId)
        }

        let nodeId = tree.id
        let id = stringIdFromInt(nodeId, includeId: includeId)
        let data = nodeId
        let requiredModelId = stringIdFromInt(nodeId + 1, includeId: includeId)
        let requiredModel = TestRequiredModel(id: requiredModelId, data: nodeId)

        return TestModel(id: id, data: data, children: testModelChildren, requiredModel: requiredModel)
    }

    /**
     Generates an immutable ProjectionTestModel from a tree object.
     */
    private class func projectionTestModelFromTree(tree: ChildrenTree, includeId: Int -> Bool) -> ProjectionTestModel {
        let testModelChildren: [ProjectionTestModel] = tree.children.map { node in
            return self.projectionTestModelFromTree(node, includeId: includeId)
        }

        let nodeId = tree.id
        let id = stringIdFromInt(nodeId, includeId: includeId)
        let data = nodeId
        let otherData = nodeId
        let requiredModelId = stringIdFromInt(nodeId + 1, includeId: includeId)
        let requiredModel = TestRequiredModel(id: requiredModelId, data: nodeId)

        return ProjectionTestModel(id: id, data: data, otherData: otherData, children: testModelChildren, requiredModel: requiredModel)
    }

    /**
    Use a breadth first search to generate a tree with a certain number of nodes.
    */
    private class func childrenTreeWithTotalNodes(nodes: Int, branchingFactor: Int, startingId: Int) -> ChildrenTree {
        var nodeQueue = [ChildrenTree]()

        var currentId = startingId
        let rootNode = ChildrenTree(id: currentId)
        // Add 2 each time to the id to save one for TestRequiredModel
        currentId += 2
        nodeQueue.append(rootNode)

        var remainingNodes = nodes - 1
        while remainingNodes > 0 {
            // Pop from the queue
            let currentNode = nodeQueue[0]
            nodeQueue.removeAtIndex(0)

            let numberOfChildren = min(remainingNodes, branchingFactor)
            for _ in 0..<numberOfChildren {
                let newChild = ChildrenTree(id: currentId)
                currentId += 2
                currentNode.children.append(newChild)
                // Also, let's add it to the queue
                nodeQueue.append(newChild)
                remainingNodes -= 1
            }
        }

        return rootNode
    }
    
    private class func stringIdFromInt(id: Int, includeId: Int -> Bool) -> String? {
        if includeId(id) {
            return "\(id)"
        } else {
            return nil
        }
    }
    
    private class ChildrenTree {
        let id: Int
        var children = [ChildrenTree]()
        
        init(id: Int) {
            self.id = id
        }
    }
}
