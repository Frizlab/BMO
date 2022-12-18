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

import HasResult



public final class LocalDbImportOperation<Bridge : BridgeProtocol> : Operation, HasResult {
	
	public enum Request {
		
		case finishedRemoteOperation(Bridge.RemoteDb.RemoteOperation, userInfo: Bridge.UserInfo, bridge: Bridge)
		case bridgeObjects(Bridge.BridgeObjects)
		case genericLocalDbObjects([GenericLocalDbObject])
		
	}
	public typealias RequestResult = LocalDbChanges<Bridge.LocalDb.DbObject, Bridge.BridgeObjects.Metadata>?
	public typealias RequestError = BMO.RequestError<Bridge>
	
	public typealias GenericLocalDbObject = BMO.GenericLocalDbObject<Bridge.LocalDb.DbObject, Bridge.LocalDb.UniquingID, Bridge.BridgeObjects.Metadata>
	public typealias UniquingIDsPerEntities = [Bridge.LocalDb.DbObject.DbEntityDescription: Set<Bridge.LocalDb.UniquingID>]
	
	public var request: Request
	public var localDb: Bridge.LocalDb
	/**
	 A request helper.
	 
	 The helper can be set to get notified at key points of the import.
	 Only the willImport and didImport methods of the helper protocol will be called from this operation:
	  the other do not make sense in the context of a local db import. */
	public var helper: Bridge.RequestHelper?
	/**
	 The importer to use for the actual import phase.
	 
	 In theory the importer is given by the helper.
	 The helper being optional for the local db import operation, we require the importer be given explicitly.
	 
	 The importer can be nil, in which case no import will be done.
	 This may seem useless, but in the context of a “finished remote operation” request, the results of the operation will still be validated even if the import is skipped. */
	public var importer: Bridge.RequestHelper.LocalDbImporter?
	
	public var startedOnContext: Bool
	
	public private(set) var result: Result<RequestResult, Error> {
		get {lock.withLock{ _result }}
		set {lock.withLock{ _result = newValue }}
	}
	
	init(request: Request, localDb: Bridge.LocalDb, helper: Bridge.RequestHelper? = nil, importer: Bridge.RequestHelper.LocalDbImporter?, startedOnContext: Bool = false) {
		self.request = request
		self.localDb = localDb
		self.helper = helper
		self.importer = importer
		
		self.startedOnContext = startedOnContext
	}
	
	public override func main() {
		result = .failure(OperationLifecycleError.operationInProgress)
		
		do {
			/* Step 4: Retrieve the bridge objects from the finished remote operation. */
			switch request {
				case let .finishedRemoteOperation(operation, userInfo: userInfo, bridge: bridge):
					try startFrom(finishedRemoteOperation: operation, userInfo: userInfo, bridge: bridge)
					
				case let .bridgeObjects(bridgeObjects):
					try startFrom(bridgeObjects: bridgeObjects)
					
				case let .genericLocalDbObjects(objects):
					try startFrom(genericLocalDbObjects: objects)
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
		guard importer != nil else {
			/* No need to continue if we do not have an importer. */
			return result = .success(nil)
		}
		var uniquingIDsPerEntities = UniquingIDsPerEntities()
		let genericLocalDbObjects = try GenericLocalDbObject.objects(
			from: bridgeObjects, uniquingIDsPerEntities: &uniquingIDsPerEntities, taskCancelled: { self.isCancelled }
		) !> RequestError.remoteToLocalObjects()
		/* Next step. */
		try startFrom(genericLocalDbObjects: genericLocalDbObjects, uniquingIDsPerEntities: uniquingIDsPerEntities)
	}
	
	func startFrom(genericLocalDbObjects: [GenericLocalDbObject], uniquingIDsPerEntities: UniquingIDsPerEntities? = nil) throws {
		guard let importer else {
			/* No need to continue if we do not have an importer. */
			return result = .success(nil)
		}
		if startedOnContext {                                      try onContext_startFrom(genericLocalDbObjects: genericLocalDbObjects, importer: importer, uniquingIDsPerEntities: uniquingIDsPerEntities)}
		else                {try localDb.context.performAndWaitRW{ try onContext_startFrom(genericLocalDbObjects: genericLocalDbObjects, importer: importer, uniquingIDsPerEntities: uniquingIDsPerEntities) }}
	}
	
	func onContext_startFrom(genericLocalDbObjects: [GenericLocalDbObject], importer: Bridge.RequestHelper.LocalDbImporter, uniquingIDsPerEntities: UniquingIDsPerEntities? = nil) throws {
		try throwIfCancelled()
		/* From there no more cancellation is possible. */
		
		guard try (helper?.onContext_willImportRemoteResults() ?? true) !> RequestError.willImport(genericLocalDbObjects: genericLocalDbObjects) else {
			/* If the helper tells us not to import, we stop. */
			return result = .success(nil)
		}
		let dbChanges: LocalDbChanges<Bridge.LocalDb.DbObject, Bridge.Metadata>
		do {
			dbChanges = try importer.onContext_import(localRepresentations: genericLocalDbObjects, in: localDb)
		} catch {
			helper?.onContext_didFailImportingRemoteResults(error)
			throw RequestError.import(error, genericLocalDbObjects: genericLocalDbObjects)
		}
		try helper?.onContext_didImportRemoteResults(dbChanges) !> RequestError.didImport(genericLocalDbObjects: genericLocalDbObjects)
	}
	
}
