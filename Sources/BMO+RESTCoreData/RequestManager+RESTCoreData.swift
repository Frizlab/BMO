/*
Copyright 2019 happn

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License. */

import CoreData
import Foundation
import os.log

import BMO
import BMO_CoreData
import RESTUtils



extension RequestManager {
	
	/* **********************
	   MARK: - Fetch Requests
	   ********************** */
	
	/* **********************************************************
	   MARK: → Retrieving objects before and after back operation
	   ********************************************************** */
	
	/**
	 Fetches **one** object of the given type.
	 If ever there were more than one object matching the given id, the first is returned and a warning is printed in the logs.
	 (If there are no remoteId given, there must be one object of the given entity in the db.)
	 
	 Does **not** throw.
	 If an error occurred fetching the object from Core Data, the error will silently be ignored and the returned object will be `nil`.
	 
	 The handler (if any) is called **on the context**.
	 
	 The handler _might_ be called before the function returns (in case there is a problem creating the back operations for instance). */
	@available(macOS 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *)
	public func unsafeFetchObject<Bridge, Object : NSManagedObject>(
		withRemoteId remoteId: String?, flatifiedFields: String? = nil, keyPathPaginatorInfo: [String: Any]? = nil, remoteIdAttributeName: String = "remoteId",
		fetchType: RESTCoreDataFetchRequest.FetchType = .always,
		onContext context: NSManagedObjectContext, bridge: Bridge? = nil,
		handler: ((_ fetchedObject: Object?, _ fullResponse: Result<BridgeBackRequestResult<Bridge>, Error>) -> Void)? = nil
	) -> (fetchedObject: Object?, operation: BackRequestOperation<RESTCoreDataFetchRequest, Bridge>)
	{
		return unsafeFetchObject(ofEntity: Object.entity(), withRemoteId: remoteId, flatifiedFields: flatifiedFields, keyPathPaginatorInfo: keyPathPaginatorInfo, remoteIdAttributeName: remoteIdAttributeName, fetchType: fetchType, onContext: context, bridge: bridge, handler: handler)
	}
	
	/* iOS 8 & 9 version of the method above. */
	public func unsafeFetchObject<Bridge, Object: NSManagedObject>(
		ofEntity entity: NSEntityDescription, withRemoteId remoteId: String?, flatifiedFields: String? = nil, keyPathPaginatorInfo: [String: Any]? = nil, remoteIdAttributeName: String = "remoteId",
		fetchType: RESTCoreDataFetchRequest.FetchType = .always,
		onContext context: NSManagedObjectContext, bridge: Bridge? = nil,
		handler: ((_ fetchedObject: Object?, _ fullResponse: Result<BridgeBackRequestResult<Bridge>, Error>) -> Void)? = nil
	) -> (fetchedObject: Object?, operation: BackRequestOperation<RESTCoreDataFetchRequest, Bridge>)
	{
		/* Creating the fetch request. */
		let fetchRequest = RequestManager.fetchRequestForFetchingObject(ofEntity: entity, withRemoteId: remoteId, remoteIdAttributeName: remoteIdAttributeName)
		
		/* Retrieving the object. */
		let object = (try? context.fetch(fetchRequest))?.first as! Object?
#if DEBUG
		if let c = try? context.count(for: fetchRequest), c > 1 {
			if #available(macOS 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {
				BMOConfig.oslog.flatMap{ os_log("Got %d results where at most 1 was expected.", log: $0, type: .info, c) }
			}
		}
#endif
		
		/* Creating and running the operation. */
		return (fetchedObject: object, operation: fetchObject(fromFetchRequest: fetchRequest, withFlatifiedFields: flatifiedFields, keyPathPaginatorInfo: keyPathPaginatorInfo, fetchType: fetchType, onContext: context, bridge: bridge, handler: handler))
	}
	
	public func unsafeFetchObject<Bridge, Object : NSManagedObject>(
		fromFetchRequest fetchRequest: NSFetchRequest<NSFetchRequestResult>, additionalRequestInfo: AdditionalRESTRequestInfo<NSPropertyDescriptionHashableWrapper>?,
		fetchType: RESTCoreDataFetchRequest.FetchType = .always,
		onContext context: NSManagedObjectContext, bridge: Bridge? = nil,
		handler: ((_ fetchedObject: Object?, _ fullResponse: Result<BridgeBackRequestResult<Bridge>, Error>) -> Void)? = nil
	) -> (fetchedObject: Object?, operation: BackRequestOperation<RESTCoreDataFetchRequest, Bridge>)
	{
		/* Retrieving the object. */
		let object = (try? context.fetch(fetchRequest))?.first as! Object?
#if DEBUG
		if let c = try? context.count(for: fetchRequest), c > 1 {
			if #available(macOS 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {
				BMOConfig.oslog.flatMap{ os_log("Got %d results where at most 1 was expected.", log: $0, type: .info, c) }
			}
		}
#endif
		
		/* Creating and running the operation. */
		return (fetchedObject: object, operation: fetchObject(fromFetchRequest: fetchRequest, additionalRequestInfo: additionalRequestInfo, fetchType: fetchType, onContext: context, bridge: bridge, handler: handler))
	}
	
	/**
	 Fetches objects fulfilling the given fetch request.
	 
	 Does **not** throw.
	 If an error occurred fetching the objects from Core Data, the error will silently be ignored and the returned objects will be `[]`.
	 
	 The handler (if any) is called **on the context**.
	 
	 The handler _might_ be called before the function returns (in case there is a problem creating the back operations for instance). */
	public func unsafeFetchObjects<Bridge, Object : NSManagedObject>(
		fromFetchRequest fetchRequest: NSFetchRequest<NSFetchRequestResult>, withFlatifiedFields flatifiedFields: String? = nil, paginatorInfo: Any? = nil,
		fetchType: RESTCoreDataFetchRequest.FetchType = .always,
		onContext context: NSManagedObjectContext, bridge: Bridge? = nil,
		handler: ((_ fetchedObjects: [Object], _ response: Result<BridgeBackRequestResult<Bridge>, Error>) -> Void)? = nil
	) -> (fetchedObjects: [Object], operation: BackRequestOperation<RESTCoreDataFetchRequest, Bridge>)
	{
		let objects = (try? context.fetch(fetchRequest)) as! [Object]? ?? []
		return (fetchedObjects: objects, operation: fetchObjects(fromFetchRequest: fetchRequest, withFlatifiedFields: flatifiedFields, paginatorInfo: paginatorInfo, fetchType: fetchType, onContext: context, bridge: bridge, handler: handler))
	}
	
	/* ***********************************************
	   MARK: → Retrieving objects after back operation
	   *********************************************** */
	
	@discardableResult
	@available(macOS 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *)
	public func fetchObject<Bridge, Object : NSManagedObject>(
		withRemoteId remoteId: String?, flatifiedFields: String? = nil, keyPathPaginatorInfo: [String: Any]? = nil, remoteIdAttributeName: String = "remoteId",
		fetchType: RESTCoreDataFetchRequest.FetchType = .always,
		onContext context: NSManagedObjectContext, bridge: Bridge? = nil,
		handler: ((_ fetchedObject: Object?, _ fullResponse: Result<BridgeBackRequestResult<Bridge>, Error>) -> Void)? = nil
	) -> BackRequestOperation<RESTCoreDataFetchRequest, Bridge>
	{
		return fetchObject(ofEntity: Object.entity(), withRemoteId: remoteId, flatifiedFields: flatifiedFields, keyPathPaginatorInfo: keyPathPaginatorInfo, remoteIdAttributeName: remoteIdAttributeName, fetchType: fetchType, onContext: context, bridge: bridge, handler: handler)
	}
	
	@discardableResult
	public func fetchObject<Bridge, Object : NSManagedObject>(
		ofEntity entity: NSEntityDescription, withRemoteId remoteId: String?, flatifiedFields: String? = nil, keyPathPaginatorInfo: [String: Any]? = nil, remoteIdAttributeName: String = "remoteId",
		fetchType: RESTCoreDataFetchRequest.FetchType = .always,
		onContext context: NSManagedObjectContext, bridge: Bridge? = nil,
		handler: ((_ fetchedObject: Object?, _ fullResponse: Result<BridgeBackRequestResult<Bridge>, Error>) -> Void)? = nil
	) -> BackRequestOperation<RESTCoreDataFetchRequest, Bridge>
	{
		let fetchRequest = RequestManager.fetchRequestForFetchingObject(ofEntity: entity, withRemoteId: remoteId, remoteIdAttributeName: remoteIdAttributeName)
		return fetchObject(fromFetchRequest: fetchRequest, withFlatifiedFields: flatifiedFields, keyPathPaginatorInfo: keyPathPaginatorInfo, fetchType: fetchType, onContext: context, bridge: bridge, handler: handler)
	}
	
	@discardableResult
	public func fetchObject<Bridge, Object : NSManagedObject>(
		fromFetchRequest fetchRequest: NSFetchRequest<NSFetchRequestResult>, withFlatifiedFields flatifiedFields: String? = nil, keyPathPaginatorInfo: [String: Any]? = nil,
		fetchType: RESTCoreDataFetchRequest.FetchType = .always,
		onContext context: NSManagedObjectContext, bridge: Bridge? = nil,
		handler: ((_ fetchedObject: Object?, _ fullResponse: Result<BridgeBackRequestResult<Bridge>, Error>) -> Void)? = nil
	) -> BackRequestOperation<RESTCoreDataFetchRequest, Bridge>
	{
		let entity = (context.persistentStoreCoordinator?.managedObjectModel.entitiesByName[fetchRequest.entityName!])!
		return fetchObject(fromFetchRequest: fetchRequest, additionalRequestInfo: AdditionalRESTRequestInfo(flatifiedFields: flatifiedFields, inEntity: entity, keyPathPaginatorInfo: keyPathPaginatorInfo), fetchType: fetchType, onContext: context, bridge: bridge, handler: handler)
	}
	
	@discardableResult
	public func fetchObject<Bridge, Object : NSManagedObject>(
		fromFetchRequest fetchRequest: NSFetchRequest<NSFetchRequestResult>, additionalRequestInfo: AdditionalRESTRequestInfo<NSPropertyDescriptionHashableWrapper>?,
		fetchType: RESTCoreDataFetchRequest.FetchType = .always,
		onContext context: NSManagedObjectContext, bridge: Bridge? = nil,
		handler: ((_ fetchedObject: Object?, _ fullResponse: Result<BridgeBackRequestResult<Bridge>, Error>) -> Void)? = nil
	) -> BackRequestOperation<RESTCoreDataFetchRequest, Bridge>
	{
		let bmoRequest = RESTCoreDataFetchRequest(context: context, fetchRequest: fetchRequest, fetchType: fetchType, additionalInfo: additionalRequestInfo)
		let handler = handler.flatMap{ originalHandler in
			return { (_ response: Result<BackRequestResult<RESTCoreDataFetchRequest, Bridge>, Error>) -> Void in
				context.perform {
					let object = (try? context.fetch(fetchRequest))?.first as! Object?
#if DEBUG
					if let c = try? context.count(for: fetchRequest), c > 1 {
						if #available(macOS 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {
							BMOConfig.oslog.flatMap{ os_log("Got %d results where at most 1 was expected.", log: $0, type: .info, c) }
						}
					}
#endif
					
					originalHandler(object, response.simpleBackRequestResult())
				}
			}
		}
		return operation(forBackRequest: bmoRequest, withBridge: bridge, autoStart: true, handler: handler)
	}
	
	@discardableResult
	public func fetchObjects<Bridge, Object : NSManagedObject>(
		fromFetchRequest fetchRequest: NSFetchRequest<NSFetchRequestResult>, withFlatifiedFields flatifiedFields: String? = nil, paginatorInfo: Any? = nil,
		fetchType: RESTCoreDataFetchRequest.FetchType = .always,
		onContext context: NSManagedObjectContext, bridge: Bridge? = nil,
		handler: ((_ fetchedObjects: [Object], _ response: Result<BridgeBackRequestResult<Bridge>, Error>) -> Void)? = nil
	) -> BackRequestOperation<RESTCoreDataFetchRequest, Bridge>
	{
		let entity = (context.persistentStoreCoordinator?.managedObjectModel.entitiesByName[fetchRequest.entityName!])!
		let bmoRequest = RESTCoreDataFetchRequest(context: context, fetchRequest: fetchRequest, fetchType: fetchType, additionalInfo: AdditionalRESTRequestInfo(flatifiedFields: flatifiedFields, inEntity: entity, paginatorInfo: paginatorInfo))
		let handler = handler.flatMap{ originalHandler in
			return { (_ response: Result<BackRequestResult<RESTCoreDataFetchRequest, Bridge>, Error>) -> Void in
				context.perform {
					let objects = (try? context.fetch(fetchRequest)) as! [Object]? ?? []
					
					originalHandler(objects, response.simpleBackRequestResult())
				}
			}
		}
		return operation(forBackRequest: bmoRequest, withBridge: bridge, autoStart: true, handler: handler)
	}
	
	/* ******************************
	   MARK: → Not retrieving objects
	   ****************************** */
	
	/**
	 Creates and starts an operation for fetching and importing the object with the given properties from the back.
	 
	 The handler (if any) **won't** be called on the context. */
	@discardableResult
	public func fetchObject<Bridge>(
		ofEntity entity: NSEntityDescription, withRemoteId remoteId: String, flatifiedFields: String? = nil, keyPathPaginatorInfo: [String: Any]? = nil, remoteIdAttributeName: String = "remoteId",
		fetchType: RESTCoreDataFetchRequest.FetchType = .always,
		onContext context: NSManagedObjectContext, bridge: Bridge? = nil,
		handler: ((_ response: Result<BridgeBackRequestResult<Bridge>, Error>) -> Void)? = nil
	) -> BackRequestOperation<RESTCoreDataFetchRequest, Bridge>
	{
		let fetchRequest = NSFetchRequest<NSFetchRequestResult>()
		fetchRequest.entity = entity
		fetchRequest.predicate = NSPredicate(format: "%K == %@", remoteIdAttributeName, remoteId)
		return operationForFetchingObjects(fromFetchRequest: fetchRequest, additionalRequestInfo: AdditionalRESTRequestInfo(flatifiedFields: flatifiedFields, inEntity: entity, keyPathPaginatorInfo: keyPathPaginatorInfo), fetchType: fetchType, onContext: context, bridge: bridge, autoStart: true, handler: handler)
	}
	
	/**
	 Creates and starts an operation for fetching and importing the objects with the given properties from the back.
	 
	 The handler (if any) **won't** be called on the context. */
	@discardableResult
	public func fetchObjects<Bridge>(
		fromFetchRequest fetchRequest: NSFetchRequest<NSFetchRequestResult>, withFlatifiedFields flatifiedFields: String? = nil, paginatorInfo: Any? = nil,
		fetchType: RESTCoreDataFetchRequest.FetchType = .always,
		onContext context: NSManagedObjectContext, bridge: Bridge? = nil,
		handler: ((_ response: Result<BridgeBackRequestResult<Bridge>, Error>) -> Void)? = nil
	) -> BackRequestOperation<RESTCoreDataFetchRequest, Bridge>
	{
		let entity = (context.persistentStoreCoordinator?.managedObjectModel.entitiesByName[fetchRequest.entityName!])!
		return fetchObjects(fromFetchRequest: fetchRequest, additionalRequestInfo: AdditionalRESTRequestInfo(flatifiedFields: flatifiedFields, inEntity: entity, paginatorInfo: paginatorInfo), fetchType: fetchType, onContext: context, bridge: bridge, handler: handler)
	}
	
	/**
	 Creates and starts an operation for fetching and importing the objects with the given properties from the back.
	 
	 The handler (if any) **won't** be called on the context. */
	@discardableResult
	public func fetchObjects<Bridge>(
		fromFetchRequest fetchRequest: NSFetchRequest<NSFetchRequestResult>, additionalRequestInfo: AdditionalRESTRequestInfo<NSPropertyDescriptionHashableWrapper>?,
		fetchType: RESTCoreDataFetchRequest.FetchType = .always,
		onContext context: NSManagedObjectContext, bridge: Bridge? = nil,
		preCompletionHandler: ((_ importResults: ImportResult<NSManagedObjectContext>) throws -> Void)? = nil,
		handler: ((_ response: Result<BridgeBackRequestResult<Bridge>, Error>) -> Void)? = nil
	) -> BackRequestOperation<RESTCoreDataFetchRequest, Bridge>
	{
		return operationForFetchingObjects(fromFetchRequest: fetchRequest, additionalRequestInfo: additionalRequestInfo, fetchType: fetchType, onContext: context, bridge: bridge, autoStart: true, preCompletionHandler: preCompletionHandler, handler: handler)
	}
	
	public func operationForFetchingObjects<Bridge>(
		fromFetchRequest fetchRequest: NSFetchRequest<NSFetchRequestResult>, additionalRequestInfo: AdditionalRESTRequestInfo<NSPropertyDescriptionHashableWrapper>?,
		fetchType: RESTCoreDataFetchRequest.FetchType,
		onContext context: NSManagedObjectContext, bridge: Bridge? = nil, autoStart: Bool,
		preCompletionHandler: ((_ importResults: ImportResult<NSManagedObjectContext>) throws -> Void)? = nil,
		handler: ((_ response: Result<BridgeBackRequestResult<Bridge>, Error>) -> Void)? = nil
	) -> BackRequestOperation<RESTCoreDataFetchRequest, Bridge>
	{
		let bmoRequest = RESTCoreDataFetchRequest(context: context, fetchRequest: fetchRequest, fetchType: fetchType, additionalInfo: additionalRequestInfo, leaveBridgeHandler: nil, preImportHandler: nil, preCompletionHandler: preCompletionHandler)
		let handler = handler.flatMap{ originalHandler in
			return { (_ response: Result<BackRequestResult<RESTCoreDataFetchRequest, Bridge>, Error>) -> Void in
				originalHandler(response.simpleBackRequestResult())
			}
		}
		return operation(forBackRequest: bmoRequest, withBridge: bridge, autoStart: autoStart, handler: handler)
	}
	
	/* *********************
	   MARK: - Save Requests
	   ********************* */
	
	/**
	 Saves the given objects on the back and saves (or rollbacks) the local context.
	 
	 All given objects **must** be on the given context.
	 
	 If `nil` is given for the objects to save on the remote, all the inserted, modified or deleted objects will be saved.
	 
	 The handler is **NOT** called on the context. */
	@discardableResult
	public func unsafeSave<Bridge>(
		context: NSManagedObjectContext, objectsToSaveOnRemote objects: [NSManagedObject]?, additionalRequestInfo: AdditionalRESTRequestInfo<NSPropertyDescriptionHashableWrapper>? = nil, rollbackInsteadOfSave: Bool = false,
		bridge: Bridge? = nil,
		handler: ((_ response: Result<BackRequestResult<RESTCoreDataSaveRequest, Bridge>, Error>) -> Void)? = nil
	) -> BackRequestOperation<RESTCoreDataSaveRequest, Bridge>?
	{
		return unsafeOperationForSaving(context: context, objectsToSaveOnRemote: objects, additionalRequestInfo: additionalRequestInfo, saveWorkflow: rollbackInsteadOfSave ? .rollbackBeforeBackReturns : .saveBeforeBackReturns, bridge: bridge, autoStart: true, handler: handler)
	}
	
	/**
	 Saves the given objects on the back and saves the local context after the back returns.
	 
	 All given objects **must** be on the given context.
	 
	 If `nil` is given for the objects to save on the remote, all the inserted, modified or deleted objects will be saved.
	 
	 The handler is **NOT** called on the context. */
	@discardableResult
	public func unsafeSaveAfterBackReturns<Bridge>(
		context: NSManagedObjectContext, objectsToSaveOnRemote objects: [NSManagedObject]?, additionalRequestInfo: AdditionalRESTRequestInfo<NSPropertyDescriptionHashableWrapper>? = nil,
		bridge: Bridge? = nil,
		handler: ((_ response: Result<BackRequestResult<RESTCoreDataSaveRequest, Bridge>, Error>) -> Void)? = nil
	) -> BackRequestOperation<RESTCoreDataSaveRequest, Bridge>?
	{
		return unsafeOperationForSaving(context: context, objectsToSaveOnRemote: objects, additionalRequestInfo: additionalRequestInfo, saveWorkflow: .saveAfterBackReturns, bridge: bridge, autoStart: true, handler: handler)
	}
	
	public func unsafeOperationForSaving<Bridge>(
		context: NSManagedObjectContext, objectsToSaveOnRemote objects: [NSManagedObject]?, additionalRequestInfo: AdditionalRESTRequestInfo<NSPropertyDescriptionHashableWrapper>? = nil, saveWorkflow: RESTCoreDataSaveRequest.SaveWorkflow = .saveBeforeBackReturns,
		bridge: Bridge? = nil,
		autoStart: Bool, handler: ((_ response: Result<BackRequestResult<RESTCoreDataSaveRequest, Bridge>, Error>) -> Void)? = nil
	) -> BackRequestOperation<RESTCoreDataSaveRequest, Bridge>?
	{
		let op = operation(forBackRequest: RESTCoreDataSaveRequest(db: context, additionalInfo: additionalRequestInfo, objectsToSave: objects, saveWorkflow: saveWorkflow), withBridge: bridge, autoStart: false, handler: handler)
		if autoStart {
			do    {try op.unsafePrepareStart()}
			catch {handler?(.failure(error)); return nil}
			op.start()
		}
		return op
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private static func fetchRequestForFetchingObject(ofEntity entity: NSEntityDescription, withRemoteId remoteId: String?, remoteIdAttributeName: String = "remoteId") -> NSFetchRequest<NSFetchRequestResult> {
		let fetchRequest = NSFetchRequest<NSFetchRequestResult>(); fetchRequest.entity = entity; fetchRequest.fetchLimit = 1
		if let remoteId = remoteId {fetchRequest.predicate = NSPredicate(format: "%K == %@", remoteIdAttributeName, remoteId)}
		return fetchRequest
	}
	
}
