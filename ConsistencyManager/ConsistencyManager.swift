// © 2016 LinkedIn Corp. All rights reserved.
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at  http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.

import Foundation
import UIKit

/**
 This is the main class for the library and contains most of the logic. For a detailed overview, please check the docs.

 ### Overview

 This class manages a list of listeners and ids (that identify the model that the listener is listening to).
 When you post an update to the consistency manager, it will regenerate new models for any applicable listener.
 It then notifies the listener of these changes.

 Given a model, any class can listen to updates on this model.
 Whenever anything in this model should change, the consistency manager will generate a new model
 and call the ConsistencyManagerListener delegate method with this new model.
 All models must adhere to the ConsistencyManagerModel protocol.

 ### API

 The two important APIs that you will mainly use in this class are:

 `listenForUpdates(listener: ConsistencyManagerListener)`
 `updateWithNewModel(model: ConsistencyManagerModel, context: Any? = nil)`

 These APIs allow you to start listening for updates on a model and register new updates.
 Anytime you change a model locally, you should call updateWithNewModel to propegate these changes.

 Additionally you have the following APIs to use if you choose to
 have your listener temporarily pause (and later resume) listening to updates:

 `pauseListeningForUpdates(listener: ConsistencyManagerListener)`
 `resumeListeningForUpdates(listener: ConsistencyManagerListener)`

 #### Removing Listeners

 In general, we recommend you don't remove listeners manually because it isn't necessary.
 The consistency manager does not hold strong references to any models or listeners.
 However, if you want to manually remove a listener, see `removeListener(listener: ConsistencyManagerListener)`
 */
public class ConsistencyManager {

    // MARK: - Public ivars

    /// Delegate for the consistency manager. Highly recommended to implement for useful callbacks.
    public weak var delegate: ConsistencyManagerDelegate?

    /**
     Periodically, the consistency manager cleans up after itself.
     This is a relatively quick process, and since the memory footprint of the library in general is small, it's not an important thing to worry about.
     Default is 5 mins. It will also clean up automatically on any memory warnings.

     If you set this to zero, then garbage collection is considered disabled.
     The ConsistencyManager will still attempt to clean up memory if the application receives a memory warning.

     This variable is not thread-safe. You should only access this on the main thread.
     */
    public var garbageCollectionInterval: NSTimeInterval = 300

    // MARK: - Private ivars

    /**
     This is a dictionary of id: listeners.
     id is a string and refers to the model to which the listener is listening.
     listeners is a weak array of ConsistencyManagerListener objects.

     This should only be accessed on the dispatchQueue.
    */
    var listeners = [String: WeakListenerArray]()

    /**
     We expect fast lookup (regardless of O(n) searches) because listeners are typically view controllers
     and most apps will not have too many.
     This will only be accessed (read/write) on the main thread.
     */
    var pausedListeners = [PausedListener]()

    /**
     Private queue used for all the real work this library does. It's serial so all the requests to this class are made in order.
     */
    let dispatchQueue = dispatch_queue_create("com.consistencyManager.internalQueue", DISPATCH_QUEUE_SERIAL)

    /// Small class which listens for memory warnings. When we get a memory warning, we'll purge as much memory as we can.
    private let memoryWarningListener = MemoryWarningListener()

    // MARK: - Initializers

    /// Singleton accessor for the consistency manager.
    public static let sharedInstance = ConsistencyManager()

    /**
     Designated initializer.
     */
    public init() {
        memoryWarningListener.delegate = self
        // Doing this in the next tick to give the caller a chance to set garbageCollectionInterval
        dispatch_async(dispatch_get_main_queue()) { 
            self.startGarbageCollection()
        }
    }

    // MARK: - Public Functions

    // MARK: Listening

    /**
     Subscribe for updates on the listener's current model. Note that here you pass in the listener and not the model.
     The model will be retrieved with the currentModel method.
     Note that calling this method on a paused listener will not unpause it.
     - parameter listener: The consistency manager listener that is listening to a model
    */
    public func listenForUpdates(listener: ConsistencyManagerListener) {
        let model = listener.currentModel()
        if let model = model {
            listenForUpdates(listener, onModel: model)
        }
        // Else they are listening to nothing. Let's not remove them though, since we are on a different thread, so timing issues could cause bugs.
    }

    /**
     Call this method if you want to listen to a specific model. Usually, this is unnecssary and you should just use listenForUpdates(listener).
     This is necessary if you manually update a model and change only part of it.
     Note that calling this method on a paused listener will not unpause it.
     For a performance optimization, you may only want to add yourself as a listener for this new change (and not the whole model again).
     - parameter listener: the consistency manager
     - parameter onModel: the model you want to listen to with this listener
     */
    public func listenForUpdates(listener: ConsistencyManagerListener, onModel model: ConsistencyManagerModel) {
        dispatch_async(dispatchQueue) {
            self.addListener(listener, recursivelyToChildModels: model)
        }
    }

    /**
     Remove a listener from the consistency manager. This isn't actually necessary to call since all references are weak, but it leaves the option to you.

     You should NOT call this from deinit since the model is currently being deallocated.
     Calling this in deinit will be a no-op.
     - parameter listener: the listener you want to remove from the consistency manager
     */
    public func removeListener(listener: ConsistencyManagerListener) {
        // Using a weak variable here in case people try calling this during deinit
        // This avoids the crash which occurs if someone calls this in deinit
        // If we lose a reference to it, it's ok since removing a listener isn't a key operation
        weak var listener = listener
        if let index = self.pausedListeners.indexOf({ listener === $0.listener }) {
            self.pausedListeners.removeAtIndex(index)
        }
        dispatch_async(dispatchQueue) {
            for (key, listenerArray) in self.listeners {
                // Let's map the listener array so that we remove any occurance of the listener
                var newListeners = listenerArray.map { element in
                    if let element = element {
                        if element === listener {
                            return nil
                        }
                    }
                    return element
                }
                // Do some cleanup
                newListeners.prune()
                self.listeners[key] = newListeners
            }
        }
    }

    // MARK: Pausing and Resuming Listening to Updates

    /**
     Temporarily ignore any updates on the current model. Use removeListener(listener: ConsistencyManagerListener) instead if you
     know that you will not ever need to resume listening to updates.
     Once you start listening again, you will get all the changes that you missed via the modelUpdated delegate method
     with the most updated model at that point, and you will get the most recent context (only) as well.

     If you pause an already paused listener, it is a no-op.

     The context and change lists are initially nil and empty, respectively, because they are only passed through when
     the delegate method is called.

     This should only be called on the main thread.
     - parameter listener: The consistency manager listener that is currently listening to a model
    */
    public func pauseListeningForUpdates(listener: ConsistencyManagerListener) {
        if !isPaused(listener) {
            let pausedListener = PausedListener(listener: listener, updatedModel: listener.currentModel(), mostRecentContext: nil, modelUpdates: ModelUpdates(changedModelIds: [], deletedModelIds: []))
            pausedListeners.append(pausedListener)
        }
    }

    /**
     Call this method on a paused listener to have it start listening to updates again.
     Once you resume listening, you will get the result of all the changes that you missed in one update via the modelUpdated
     delegate method, and continue to get future updates. Note that you will only have access to the last context (not intermediate ones) passed
     in via a model update, just as you will not be able to examine intermediate model updates.

     This should only be called on the main thread.
     - parameter listener: The consistency manager listener that is currently not listening
     (i.e. has most recently called the pauseListeningForUpdates method) to a model
     */
    public func resumeListeningForUpdates(listener: ConsistencyManagerListener) {
        guard let index = pausedListeners.indexOf({ listener === $0.listener }) else {
            return
        }
        let pausedListener = pausedListeners.removeAtIndex(index)

        if pausedListener.modelUpdates.deletedModelIds.count == 0 && pausedListener.modelUpdates.changedModelIds.count == 0 {
            // We have no changes, so let's just immediately return
            return
        }

        let newModel = pausedListener.updatedModel
        guard let outdatedModel = listener.currentModel() else {
            // If our current model is nil, then we've stopped listening for changes
            // So, we should just return
            return
        }
        if let newModel = newModel where outdatedModel.isEqualToModel(newModel) {
            return
        }

        dispatch_async(dispatchQueue) {

            // Here, we are doing three steps to verify model updates.
            // When looking at batch model updates, there may be inconsistencies (such as a model which was both deleted and updated).
            // 1. We iterate over the new tree and remove anything from deleted which is still there.
            // 2. We iterate over the old tree and make sure anything in the updates list has actually changed.
            // 3. We subtract all the deleted models from updated. At this point, anything that's deleted is no longer there so an update doesn't make sense.

            var confirmedChangelist = pausedListener.modelUpdates

            if let newModel = newModel {
                var idToNewModel = [String: ConsistencyManagerModel]()

                // Traverses the updated model recursively, while adding individual model nodes and their ids to the dictionary
                // and removing any traversed nodes from the deleted models list
                self.recursivelyIterateOverModel(newModel) { model in
                    if let id = model.modelIdentifier {
                        idToNewModel[id] = model
                        confirmedChangelist.deletedModelIds.remove(id)
                    }
                }
                // Traverse the old model and remove models from the changelist that haven't actually changed.
                self.recursivelyIterateOverModel(outdatedModel) { model in
                    if let id = model.modelIdentifier,
                        let newModel = idToNewModel[id]
                        where confirmedChangelist.changedModelIds.contains(id) && newModel.isEqualToModel(model)
                    {
                        confirmedChangelist.changedModelIds.remove(id)
                    }
                }
            } else {
                // The model was deleted, so we shouldn't have any updated models
                confirmedChangelist.changedModelIds = []
            }
            // Any elements that were deleted should not be in the changed list.
            confirmedChangelist.changedModelIds.subtractInPlace(confirmedChangelist.deletedModelIds)
            dispatch_async(dispatch_get_main_queue()) {
                listener.modelUpdated(newModel, updates: confirmedChangelist, context: pausedListener.mostRecentContext)
            }
        }
    }

    /**
     Returns true if the listener is currently in a paused state.

     - parameter listener: The listener to query the paused state of.
     */
    public func isPaused(listener: ConsistencyManagerListener) -> Bool {
        return pausedListeners.contains { listener === $0.listener }
    }

    // MARK: Updating

    /**
     Update the consistency manager with a new model. This will call the updatedModel methods on zero, one or multiple listeners.
     You should call this method whenever there is a new model or a model has changed.
     You can use the context, for example, to track who made a certain update to the consistency manager.
     - parameter model: the model with which you want to update the consistency manager
     - parameter context: any context parameter, to be passed on to each listener in the delegate method
    */
    public func updateWithNewModel(model: ConsistencyManagerModel, context: Any? = nil) {
        dispatch_async(dispatchQueue) {
            let tuple = self.childrenAndListenersForModel(model)
            let optionalModelUpdates = CollectionHelpers.optionalValueDictionaryFromDictionary(tuple.modelUpdates)
            self.updateListeners(tuple.listeners, withUpdatedModels: optionalModelUpdates, context: context)
        }
    }

    /**
     This function will delete a model from the consistency manager. This will cause anyone who has this model as a subtree to update.
     The function is not recursive. It does not delete submodels of this model, just the top level model.
     The submodels of this model can still exist in other models.
     You probably don't want to do this recursively so think carefully about the consequences of this before implementing it yourself.

     WARNING: If you have a model that has a required model that is deleted, then it will call the map function with a nil child.
     The recommended way to deal with this is to cascade the delete, so the parent model will also be deleted.

     You can optionally pass in a context parameter here. You can use this to track who made a certain update to the consistency manager.
     - parameter model: the model to delete from the consistency manager
     - parameter context: anything you want to pass to each associated listener via the delegate method upon update
     */
    public func deleteModel(model: ConsistencyManagerModel, context: Any? = nil) {
        dispatch_async(dispatchQueue) {
            if let id = model.modelIdentifier {
                // First, let's get all the listeners that care about this id
                let listenersArray: [ConsistencyManagerListener] = {
                    let weakListenersArray = self.listeners[id]
                    if var weakListenersArray = weakListenersArray {
                        let returnValue = weakListenersArray.prune()
                        // Since we pruned, let's update our state
                        self.listeners[id] = weakListenersArray
                        return returnValue
                    } else {
                        return []
                    }
                }()

                // A simple update dictionary. We're just deleting a model with this id. Nothing else.
                let updatesDictionary: [String: ConsistencyManagerModel?] = [ id: nil ]
                self.updateListeners(listenersArray, withUpdatedModels: updatesDictionary, context: context)
            } else {
                dispatch_async(dispatch_get_main_queue()) {
                    self.delegate?.consistencyManager(self, failedWithCriticalError: CriticalError.DeleteIDFailure.rawValue)
                }
            }
        }
    }

    // MARK: Other

    /**
     This will remove any unnecessary memory held by the consistency manager.
     This is called automatically whenever there is a memory warning, so usually you should not need to ever call this method.
     The class also cleans up memory automatically as it is used, so you shouldn't worry about memory usage.
    */
    public func cleanMemory() {
        dispatch_async(dispatchQueue) {
            for (key, var listenersArray) in self.listeners {
                listenersArray.prune()
                // If the array has no elements now, let's remove it from the dictionary
                // Else, let's reset it (we may have removed elements)
                if listenersArray.count == 0 {
                    self.listeners[key] = nil
                } else {
                    self.listeners[key] = listenersArray
                }
            }
        }
        // Remove any PausedListener structs from our local list if the internal listener is now nil
        pausedListeners = self.pausedListeners.filter { $0.listener != nil }
    }

    /**
     This method is called periodically to clean up our memory. When called, it automatically schedules its call again, so it should not be called more than once.
     It is called once on initialization to start the process. This will cause a cleanMemory call, but that's ok since it will be basically a no-op.
     */
    private func startGarbageCollection() {
        // Saving a local variable so we only access this on the main thread
        let garbageCollectionInterval = self.garbageCollectionInterval
        // If garbageCollectionInterval is 0, this means it's disabled.
        if garbageCollectionInterval > 0 {
            // Weak here is necessary, otherwise, we'd have a retain cycle.
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(UInt64(garbageCollectionInterval) * NSEC_PER_SEC)), dispatchQueue) { [weak self] in
                self?.cleanMemory()
                dispatch_async(dispatch_get_main_queue()) {
                    self?.startGarbageCollection()
                }
            }
        }
    }

    // MARK: - Private Functions

    // MARK: Listening

    /**
    This function recusively traverses a model and adds the listener to the model and all of its children.
    */
    private func addListener(listener: ConsistencyManagerListener, recursivelyToChildModels model: ConsistencyManagerModel) {
        // Add this model as listening
        addListener(listener, toModel: model)
        // Recurse on the children
        model.forEach() { child in
            self.addListener(listener, recursivelyToChildModels: child)
        }
    }

    /**
     This method adds a listener to a single model. It is not recursive.

     It checks to see if modelIdentifier is nil, and then adds the listener in the dictionary, but only if it's not already listening.
     */
    private func addListener(listener: ConsistencyManagerListener, toModel model: ConsistencyManagerModel) {
        let id = model.modelIdentifier
        if let id = id {
            var weakArray: WeakListenerArray = {
                let weakArray = self.listeners[id]
                if let weakArray = weakArray {
                    return weakArray
                } else {
                    return WeakListenerArray()
                }
            }()

            let alreadyInArray: Bool = {
                for i in 0..<weakArray.count {
                    if let object = weakArray[i] {
                        if object === listener {
                            return true
                        }
                    }
                }
                return false
            }()

            if !alreadyInArray {
                weakArray.append(listener)
                listeners[id] = weakArray
            }
        }
    }

    /**
     This is a wrapper function to provide a functional API.
     It takes in a model and returns all the models contained in the model (flattened in a dictionary with ID for lookup).
     It also has an array of listeners that need to be updated because of this model change.
     */
    private func childrenAndListenersForModel(model: ConsistencyManagerModel) -> (modelUpdates: [String: ConsistencyManagerModel], listeners: [ConsistencyManagerListener]) {
        let updates = DictionaryHolder<String, ConsistencyManagerModel>()
        let listenersArray = ArrayHolder<ConsistencyManagerListener>()
        childrenAndListenersForModel(model, modelUpdates: updates, listenersArray: listenersArray)
        return (updates.dictionary, listenersArray.array)
    }

    /**
     This is where all the work actually gets done for childrenAndListenersForModel(model: ConsistencyManagerModel). It's implemented like this so we don't create and destroy lots of dictionaries (which is actually a huge performance hit).

     I tried doing this with inout instead of making it truly functional, but turns out that inout doesn't work very well.
     Changing to inout helped me about 10%, but after changing to a DictionaryHolder and ArrayHolder, performance was improved ~50x.
     */
    private func childrenAndListenersForModel(model: ConsistencyManagerModel, modelUpdates: DictionaryHolder<String, ConsistencyManagerModel>, listenersArray: ArrayHolder<ConsistencyManagerListener>) {

        if let id = model.modelIdentifier {
            modelUpdates.dictionary[id] = model

            // Here, we're going to take all the listeners to this model and add it to our listeners array
            // We're not going to prune the listeners array because of performance reasons (we want updates to go fast)
            let idListeners = listeners[id]
            if let idListeners = idListeners {
                for index in 0..<idListeners.count {
                    if let listener = idListeners[index] {
                        // Add listener to listeners array without duplicates
                        let contains = listenersArray.array.reduce(false) { $0 || $1 === listener }
                        if !contains {
                            listenersArray.array.append(listener)
                        }
                    }
                }
            }
        }

        model.forEach { child in
            self.childrenAndListenersForModel(child, modelUpdates: modelUpdates, listenersArray: listenersArray)
        }
    }

    /**
     Helper function which recursively visits each model in a tree, including the root object.
     */
    private func recursivelyIterateOverModel(model: ConsistencyManagerModel, visit: (ConsistencyManagerModel)->Void) {
        visit(model)
        model.forEach { child in
            self.recursivelyIterateOverModel(child, visit: visit)
        }
    }

    /**
     Given a listener and a list of updates, this function:
     Given an array of listeners and a list of updates, this function:

     For each listener:
     1. Gets the current model.
     2. Generates the new model.
     3. Generates the list of changed and deleted ids.
     4. Ensures that listener listens to all the new models that have been added.
     5. Notifies the listener of the new model change.

     In the case of this listener being in a paused state, the function updates
     the listener's PausedListener struct accordingly, without notifying the delegate.
     */
    private func updateListeners(listeners: [ConsistencyManagerListener], withUpdatedModels updatedModels: [String: ConsistencyManagerModel?], context: Any?) {

        var currentModels: [(listener: ConsistencyManagerListener, currentModel: ConsistencyManagerModel?)] = []

        // In one dispatch_sync, we'll get all of the current models for each listener
        dispatch_sync(dispatch_get_main_queue()) {
            currentModels = listeners.map { listener in
                // If the listener is paused, then use the latest model (to which it has not officially listened) to do the transformation on later.
                if let index = self.pausedListeners.indexOf({ listener === $0.listener }) {
                    return (listener, self.pausedListeners[index].updatedModel)
                } else {
                    return (listener, listener.currentModel())
                }
            }
        }

        // Given the current model, let's generate new models for each listener
        let results: [(listener: ConsistencyManagerListener, newModel: ConsistencyManagerModel?, modelUpdates: ModelUpdates)] = currentModels.flatMap { (listener, currentModel) in
            guard let currentModel = currentModel else {
                // Else the model has disappeared (so the listener isn't listening to anything anymore).
                // Let's not remove the listener though, because we could screw something up due to timing issues (we are on a different thread)
                return nil
            }
            let newModel = self.updatedModelFromOriginalModel(currentModel, updatedModels: updatedModels, context: context)
            if newModel.updates.deletedModelIds.count > 0 || newModel.updates.changedModelIds.count > 0 {
                for model in newModel.newModels {
                    // We need to listen to all our new children
                    addListener(listener, recursivelyToChildModels: model)
                }
                return (listener, newModel.model, newModel.updates)
            } else {
                // There weren't actually any changes to this model so no need to update
                return nil
            }
        }

        // Again, we're just going to use one dispatch_async.
        // In this block, we're going to return the results to the listener or update our paused listeners.
        dispatch_async(dispatch_get_main_queue()) {
            results.forEach { (listener, newModel, modelUpdates) in
                // Let's make sure the model hasn't changed since we last requested it.
                // We're just going to make sure the id is the same so it represents the same data.
                // If the id is nil, then we will still update since this represents a delete.
                if let id = newModel?.modelIdentifier,
                    let currentId = listener.currentModel()?.modelIdentifier
                    where id != currentId {
                        // The model has been changed while we were doing work, so let's just return.
                        // The next call to this function will take care of updating the model with more recent information.
                        return
                }
                if let index = self.pausedListeners.indexOf({listener === $0.listener}) {
                    let mergedChangedModels = modelUpdates.changedModelIds.union(self.pausedListeners[index].modelUpdates.changedModelIds)
                    let mergedDeletedModels = modelUpdates.deletedModelIds.union(self.pausedListeners[index].modelUpdates.deletedModelIds)
                    let mergedUpdates = ModelUpdates(changedModelIds: mergedChangedModels, deletedModelIds: mergedDeletedModels)
                    self.pausedListeners[index] = PausedListener(listener: listener, updatedModel: newModel, mostRecentContext: context, modelUpdates: mergedUpdates)
                } else {
                    listener.modelUpdated(newModel, updates: modelUpdates, context: context)
                }
            }
        }
    }

    /**
     This function uses the map functionality of the models to generate a new model given a list of modelUpdates.
     It returns a new model, a list of changes (ModelUpdates) and a list of any new models which were not contained in the old model.
     */
    private func updatedModelFromOriginalModel(model: ConsistencyManagerModel, updatedModels: [String: ConsistencyManagerModel?], context: Any?) -> (model: ConsistencyManagerModel?, updates: ModelUpdates, newModels: [ConsistencyManagerModel]) {
        if let id = model.modelIdentifier {
            if let replacementModel = updatedModels[id] {
                // The id matches, so we should replace this model with a different model
                // Important: replacementModel could actually be nil here. This is because modelUpdates[id] is actually type: ConsistencyManagerModel??.
                // So, the let statement only unwraps it once. This is a good thing since if it is nil, we want to delete the model.
                if replacementModel == nil {
                    // nil was an update, so returning it in updates
                    return (nil, ModelUpdates(changedModelIds: [], deletedModelIds: [id]), [])
                } else if let replacementModel = replacementModel where !replacementModel.isEqualToModel(model) {
                    // We've found something to replace, and there's actually an update
                    delegate?.consistencyManager(self, willReplaceModel: model, withModel: replacementModel, context: context)
                    // There may be other changed models in the subtree of the model we're replacing. Let's search to see if anything else changed.
                    var updates = changedSubmodelIdsFromModel(model, modelUpdates: updatedModels)
                    updates.insert(id)
                    return (replacementModel, ModelUpdates(changedModelIds: updates, deletedModelIds: []), [replacementModel])
                } else {
                    // We've found there's an update here, but there's no actual change. So let's short curcuit here so we don't waste time recursing.
                    return (model, ModelUpdates(changedModelIds: [], deletedModelIds: []), [])
                }
            }
        }
        // Else, this isn't the model we're looking for. Let's keep recursing.

        var updates = ModelUpdates(changedModelIds: [], deletedModelIds: [])
        var newModels = [ConsistencyManagerModel]()
        let newModel = model.map { child in
            let result = self.updatedModelFromOriginalModel(child, updatedModels: updatedModels, context: context)
            // Let's add all the updates to the array
            updates.changedModelIds.unionInPlace(result.updates.changedModelIds)
            updates.deletedModelIds.unionInPlace(result.updates.deletedModelIds)
            newModels.appendContentsOf(result.newModels)
            // Then return the new model
            return result.model
        }
        if let newModel = newModel {
            // These classes should always be the same as map should always return self
            if newModel.dynamicType != model.dynamicType {
                dispatch_async(dispatch_get_main_queue()) {
                    self.delegate?.consistencyManager(self, failedWithCriticalError: CriticalError.WrongMapClass.rawValue)
                }
            }
        }
        if let id = model.modelIdentifier {
            if newModel == nil {
                // This occurs when the current model has been deleted.
                // This has caused a cascading delete, so we should add the current model to the deleted items.
                updates.deletedModelIds.insert(id)
            } else if updates.changedModelIds.count > 0 || updates.deletedModelIds.count > 0 {
                // Some child of this model has changed which means this model has changed. So, we should add this model to the updated list
                updates.changedModelIds.insert(id)
            }
        }

        return (newModel, updates, newModels)
    }

    /**
     This function recusively inspects subtrees of a model and returns a set of all the models which have been changed.
     It does not include models which have been deleted.
     It's useful for detecting the full set of updates for an UpdateModel.
     */
    private func changedSubmodelIdsFromModel(model: ConsistencyManagerModel, modelUpdates: [String: ConsistencyManagerModel?]) -> Set<String> {
        var changedModels = Set<String>()
        model.forEach { child in
            if let id = child.modelIdentifier, let update = modelUpdates[id] {
                // Update is still an optional because the value of model updates is optional
                // We can ignore deletes because we are only looking for updated models.
                if let update = update where !update.isEqualToModel(child) {
                    // There's another update here
                    changedModels.insert(id)
                }
            }
            // Continue recursion
            changedModels.unionInPlace(self.changedSubmodelIdsFromModel(child, modelUpdates: modelUpdates))
        }
        return changedModels
    }

    // MARK: - Memory Warnings

    func applicationDidReceiveMemoryWarning(notification: NSNotification) {
        cleanMemory()
    }

    /**
     This is a simple class which listens for memory warnings and notifies the consistency manager.
     It's useful because it means we don't need to make the ConsistencyManager inherit from NSObject.
     */
    class MemoryWarningListener: NSObject {
        weak var delegate: ConsistencyManager?

        override init() {
            super.init()
            NSNotificationCenter.defaultCenter().addObserver(self, selector: "applicationDidReceiveMemoryWarning:", name: UIApplicationDidReceiveMemoryWarningNotification, object: nil)
        }

        deinit {
            NSNotificationCenter.defaultCenter().removeObserver(self)
        }

        func applicationDidReceiveMemoryWarning(notification: NSNotification) {
            delegate?.applicationDidReceiveMemoryWarning(notification)
        }
    }

    struct PausedListener {
        weak var listener: ConsistencyManagerListener?

        /// The model that is updated with all of the changes that are happening while the listener is paused
        let updatedModel: ConsistencyManagerModel?

        /// The most recent context (each intermediate context is replaced upon update)
        let mostRecentContext: Any?

        /// A list of changed and deleted models between the listener's stored model and the most updated model.
        /// Models referred to in these sets are not guaranteed to always be accurate since successive changes/adds/deletes
        /// may undo previous ones. When the listener resumes listening, final tree traversals and checks will occur
        /// before calling the delegate method with a consistency manager change and confirmed changelist.
        let modelUpdates: ModelUpdates
    }
}
