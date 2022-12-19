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
	
	public typealias RequestHelperCollection = RequestHelperCollectionForOldRuntimes<Bridge.LocalDb.DbObject, Bridge.Metadata>
	
	public typealias GenericLocalDbObject = BMO.GenericLocalDbObject<Bridge.LocalDb.DbObject, Bridge.LocalDb.UniquingID, Bridge.BridgeObjects.Metadata>
	public typealias UniquingIDsPerEntities = [Bridge.LocalDb.DbObject.DbEntityDescription: Set<Bridge.LocalDb.UniquingID>]
	
	public typealias ImporterFactory = ([GenericLocalDbObject], Bridge.Metadata?, UniquingIDsPerEntities, _ isCancelled: () -> Bool) throws -> Bridge.LocalDbImporter
	
	public var request: Request
	public var localDb: Bridge.LocalDb
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
	
	public private(set) var result: Result<RequestResult, Error> {
		get {lock.withLock{ _result }}
		set {lock.withLock{ _result = newValue }}
	}
	
	init(request: Request, localDb: Bridge.LocalDb, helper: RequestHelperCollection, importerFactory: @escaping ImporterFactory, startedOnContext: Bool = false) {
		self.request = request
		self.localDb = localDb
		self.helper = helper
		self.importerFactory = importerFactory
		
		self.startedOnContext = startedOnContext
	}
	
	public override func main() {
		result = .failure(OperationLifecycleError.operationInProgress)
		
		do {
			switch request {
				case let .finishedRemoteOperation(operation, userInfo: userInfo, bridge: bridge):
					try startFrom(finishedRemoteOperation: operation, userInfo: userInfo, bridge: bridge)
					
				case let .bridgeObjects(bridgeObjects):
					try startFrom(bridgeObjects: bridgeObjects)
					
				case let .genericLocalDbObjects(objects, rootMetadata: rootMetadata):
					try startFrom(genericLocalDbObjects: objects, rootMetadata: rootMetadata)
			}
		} catch {
			result = .failure(error)
		}
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
	private var _result: Result<RequestResult, Error> = .failure(OperationLifecycleError.operationNotStarted)
	
	private func throwIfCancelled() throws {
		guard !isCancelled else {
			throw OperationLifecycleError.cancelled
		}
	}
	
}


private extension LocalDbImportOperation {
	
	func startFrom(finishedRemoteOperation: Bridge.RemoteDb.RemoteOperation, userInfo: Bridge.UserInfo, bridge: Bridge) throws {
		try throwIfCancelled()
		guard let bridgeObjects = try bridge.bridgeObjects(for: finishedRemoteOperation, userInfo: userInfo) !> RequestError.remoteOperationToObjects(finishedRemoteOperation) else {
			return result = .success(nil)
		}
		/* Next step. */
		try startFrom(bridgeObjects: bridgeObjects)
	}
	
	func startFrom(bridgeObjects: Bridge.BridgeObjects) throws {
		try throwIfCancelled()
		var uniquingIDsPerEntities = UniquingIDsPerEntities()
		let genericLocalDbObjects = try GenericLocalDbObject.objects(
			from: bridgeObjects, uniquingIDsPerEntities: &uniquingIDsPerEntities, taskCancelled: { self.isCancelled }
		) !> RequestError.remoteToLocalObjects()
		/* Next step. */
		try startFrom(genericLocalDbObjects: genericLocalDbObjects, rootMetadata: bridgeObjects.localMetadata, uniquingIDsPerEntities: uniquingIDsPerEntities)
	}
	
	func startFrom(genericLocalDbObjects: [GenericLocalDbObject], rootMetadata: Bridge.Metadata?, uniquingIDsPerEntities: UniquingIDsPerEntities? = nil) throws {
		let uniquingIDsPerEntities = uniquingIDsPerEntities ?? {
			var res = UniquingIDsPerEntities()
			genericLocalDbObjects.forEach{ $0.insertUniquingIDsPerEntities(in: &res) }
			return res
		}()
		let importer = try importerFactory(genericLocalDbObjects, rootMetadata, uniquingIDsPerEntities, { self.isCancelled })
		if startedOnContext {                                      try onContext_startFrom(genericLocalDbObjects: genericLocalDbObjects, importer: importer, uniquingIDsPerEntities: uniquingIDsPerEntities)}
		else                {try localDb.context.performAndWaitRW{ try onContext_startFrom(genericLocalDbObjects: genericLocalDbObjects, importer: importer, uniquingIDsPerEntities: uniquingIDsPerEntities) }}
	}
	
	func onContext_startFrom(genericLocalDbObjects: [GenericLocalDbObject], importer: Bridge.LocalDbImporter, uniquingIDsPerEntities: UniquingIDsPerEntities? = nil) throws {
		try throwIfCancelled()
		/* From there no more cancellation is possible. */
		
		guard try helper.onContext_willImportRemoteResults() !> RequestError.willImport(genericLocalDbObjects: genericLocalDbObjects) else {
			/* If the helper tells us not to import, we stop. */
			return result = .success(nil)
		}
		let dbChanges: LocalDbChanges<Bridge.LocalDb.DbObject, Bridge.Metadata>
		do {
			dbChanges = try importer.onContext_import(in: localDb, taskCancelled: { self.isCancelled })
		} catch {
			helper.onContext_didFailImportingRemoteResults(error)
			throw RequestError.import(error, genericLocalDbObjects: genericLocalDbObjects)
		}
		try helper.onContext_didImportRemoteResults(dbChanges) !> RequestError.didImport(genericLocalDbObjects: genericLocalDbObjects)
		result = .success(dbChanges)
	}
	
}
