/*
Copyright 2022 happn

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License. */

import Foundation



public final class LocalDbImportOperation<Bridge : BridgeProtocol> : Operation {
	
	public enum Request {
		
		case finishedRemoteOperation(Bridge.RemoteDb.RemoteOperation, userInfo: Bridge.UserInfo, bridge: Bridge)
		case bridgeObjects(Bridge.BridgeObjects)
		case genericLocalDbObjects([GenericLocalDbObject], rootMetadata: Bridge.Metadata?)
		
	}
	public typealias RequestResult = LocalDbChanges<Bridge.LocalDb.DbObject, Bridge.BridgeObjects.Metadata>?
	public typealias RequestError = BMO.RequestError<Bridge>
	
	public typealias RequestHelperCollection = RequestHelperCollectionForOldRuntimes<Bridge.LocalDb.DbContext, Bridge.LocalDb.DbObject, Bridge.Metadata>
	
	public typealias GenericLocalDbObject = BMO.GenericLocalDbObject<Bridge.LocalDb.DbObject, Bridge.LocalDb.UniquingID, Bridge.BridgeObjects.Metadata>
	public typealias UniquingIDsPerEntities = [Bridge.LocalDb.DbObject.DbEntityDescription: Set<Bridge.LocalDb.UniquingID>]
	
	public typealias ImporterFactory = ([GenericLocalDbObject], Bridge.Metadata?, UniquingIDsPerEntities, _ cancellationCheck: () throws -> Void) throws -> Bridge.LocalDbImporter
	
	public var request: Request
	public var localDb: Bridge.LocalDb
	public var localDbContextOverride: Bridge.LocalDb.DbContext?
	public var localDbContext: Bridge.LocalDb.DbContext {localDbContextOverride ?? localDb.context}
	/**
	 A collection of request helpers.
	 
	 A helper can be used to get notified at key points of the import.
	 It is practically a part of the request: the bridge **must** return a request helper for a given request.
	 
	 In the context of a ``LocalDbImportOperation``, the original request is not known, that’s why we require the helper directly.
	 
	 We require a collection of helpers instead of just one helper because the client might be interested in getting notified/interacting with the request in addition to the bridge.
	 
	 Only the ``RequestHelperProtocol/onContext_willImportRemoteResults()``, ``RequestHelperProtocol/onContext_didImportRemoteResults(_:)`` and ``RequestHelperProtocol/onContext_didFailImportingRemoteResults(_:)``
	  methods of the helper protocol will be called from this operation:
	  the other do not make sense in the context of a local db import. */
	public var helper: RequestHelperCollection
	/**
	 The importer block to use to create the importer that will be used in the actual import phase.
	 
	 The importer should be given by the bridge.
	 In the case of a bridgeObjects or genericLocalDbObjects request, we want to avoid sending the bridge.
	 So we ask for a factory instead. */
	public var importerFactory: ImporterFactory
	
	public var startedOnContext: Bool
	
	public private(set) var result: Result<RequestResult, RequestError> {
		get {lock.withLock{ _result }}
		set {lock.withLock{ _result = newValue }}
	}
	
	/**
	 Init a `LocalDbImportOperation`.
	 
	 - Important: The `startedOnImportContext` does mean started on the **import** context, which might be different than the local db context.
	 Indeed, the import context can be changed by the request helper. */
	init(request: Request, localDb: Bridge.LocalDb, localDbContextOverride: Bridge.LocalDb.DbContext? = nil, helper: RequestHelperCollection, importerFactory: @escaping ImporterFactory, startedOnImportContext: Bool = false) {
		self.request = request
		self.localDb = localDb
		self.localDbContextOverride = localDbContextOverride
		self.helper = helper
		self.importerFactory = importerFactory
		
		self.startedOnContext = startedOnImportContext
	}
	
	public override func main() {
		result = .failure(RequestError(failureStep: .none, lifecycleError: .inProgress))
		result = { /* When possible (SE-0380), assign result directly to the switch if it’s more beautiful. */
			switch request {
				case let .finishedRemoteOperation(operation, userInfo: userInfo, bridge: bridge):
					return startFrom(finishedRemoteOperation: operation, userInfo: userInfo, bridge: bridge)
					
				case let .bridgeObjects(bridgeObjects):
					return startFrom(bridgeObjects: bridgeObjects)
					
				case let .genericLocalDbObjects(objects, rootMetadata: rootMetadata):
					return startFrom(genericLocalDbObjects: objects, rootMetadata: rootMetadata)
			}
		}()
	}
	
	public override func cancel() {
		super.cancel()
		/*nop*/
	}
	
	public override var isAsynchronous: Bool {
		return false
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private let lock = NSLock()
	private var _result: Result<RequestResult, RequestError> = .failure(RequestError(failureStep: .none, lifecycleError: .notStarted))
	
	private func throwIfCancelled() throws {
		guard !isCancelled else {
			throw OperationLifecycleError.cancelled
		}
	}
	
}


private extension LocalDbImportOperation {
	
	func startFrom(finishedRemoteOperation: Bridge.RemoteDb.RemoteOperation, userInfo: Bridge.UserInfo, bridge: Bridge) -> Result<RequestResult, RequestError> {
		do {
			try throwIfCancelled()
			guard let bridgeObjects = try bridge.bridgeObjects(for: finishedRemoteOperation, userInfo: userInfo) else {
				return .success(nil)
			}
			/* Next step. */
			return startFrom(bridgeObjects: bridgeObjects, remoteOperation: finishedRemoteOperation)
		} catch {
			helper.remoteFailed(error)
			return .failure(RequestError(failureStep: .bridge_remoteOperationToObjects, checkedUnderlyingError: error, remoteOperation: finishedRemoteOperation))
		}
	}
	
	func startFrom(bridgeObjects: Bridge.BridgeObjects, remoteOperation: Bridge.RemoteDb.RemoteOperation? = nil) -> Result<RequestResult, RequestError> {
		do {
			try throwIfCancelled()
			var uniquingIDsPerEntities = UniquingIDsPerEntities()
			let genericLocalDbObjects = try GenericLocalDbObject.objects(
				from: bridgeObjects, uniquingIDsPerEntities: &uniquingIDsPerEntities, cancellationCheck: throwIfCancelled
			)
			/* Next step. */
			return startFrom(genericLocalDbObjects: genericLocalDbObjects, rootMetadata: bridgeObjects.localMetadata, uniquingIDsPerEntities: uniquingIDsPerEntities, remoteOperation: remoteOperation)
		} catch {
			helper.remoteFailed(error)
			return .failure(RequestError(failureStep: .bridge_remoteToLocalObjects, checkedUnderlyingError: error, remoteOperation: remoteOperation))
		}
	}
	
	func startFrom(genericLocalDbObjects: [GenericLocalDbObject], rootMetadata: Bridge.Metadata?, uniquingIDsPerEntities: UniquingIDsPerEntities? = nil, remoteOperation: Bridge.RemoteDb.RemoteOperation? = nil) -> Result<RequestResult, RequestError> {
		var step: RequestError.FailureStep = .none
		do {
			guard let newContext = helper.newContextForImportingRemoteResults() ?? localDbContext else {
				/* If the helper tells us not to import, we stop. */
				return .success(nil)
			}
			
			try throwIfCancelled()
			step = .bridge_remoteToLocalObjects
			let uniquingIDsPerEntities = try uniquingIDsPerEntities ?? {
				var res = UniquingIDsPerEntities()
				try genericLocalDbObjects.forEach{ try $0.insertUniquingIDsPerEntities(in: &res, cancellationCheck: throwIfCancelled) }
				return res
			}()
			try throwIfCancelled()
			step = .bridge_importerForResults
			let importer = try importerFactory(genericLocalDbObjects, rootMetadata, uniquingIDsPerEntities, throwIfCancelled)
			if startedOnContext {return                                   onContext_startFrom(genericLocalDbObjects: genericLocalDbObjects, importer: importer, context: newContext, remoteOperation: remoteOperation)}
			else                {return localDb.context.performAndWaitRW{ onContext_startFrom(genericLocalDbObjects: genericLocalDbObjects, importer: importer, context: newContext, remoteOperation: remoteOperation) }}
		} catch {
			helper.remoteFailed(error)
			return .failure(RequestError(failureStep: step, checkedUnderlyingError: error, remoteOperation: remoteOperation))
		}
	}
	
	func onContext_startFrom(genericLocalDbObjects: [GenericLocalDbObject], importer: Bridge.LocalDbImporter, context: Bridge.LocalDb.DbContext, remoteOperation: Bridge.RemoteDb.RemoteOperation? = nil) -> Result<RequestResult, RequestError> {
		var step: RequestError.FailureStep = .none
		do {
			try throwIfCancelled()
			
			step = .helper_willImport
			guard try helper.onContext_remoteToLocal_willImportRemoteResults(context: context, cancellationCheck: throwIfCancelled) else {
				/* If the helper tells us not to import, we stop. */
				return .success(nil)
			}
			
			step = .importer_import
			let dbChanges = try importer.onContext_import(in: context, cancellationCheck: throwIfCancelled)
			
			step = .helper_didImport
			try helper.onContext_remoteToLocal_didImportRemoteResults(dbChanges, context: context, cancellationCheck: throwIfCancelled)
			
			return .success(dbChanges)
		} catch {
			helper.onContext_remoteToLocalFailed(error, context: context)
			return .failure(RequestError(failureStep: step, checkedUnderlyingError: error, remoteOperation: remoteOperation, genericLocalDbObjects: genericLocalDbObjects))
		}
	}
	
}
