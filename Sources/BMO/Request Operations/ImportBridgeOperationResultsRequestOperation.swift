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

import Foundation



public final class ImportBridgeOperationResultsRequestOperation<Bridge : BridgeProtocol> : Operation {
	
	public typealias DbRepresentationImporterResult = (importResult: ImportResult<Bridge.Db>, bridgeBackRequestResult: BridgeBackRequestResult<Bridge>)
	
	public let request: ImportBridgeOperationResultsRequest<Bridge>
	public let importer: any BackResultsImporter<Bridge>
	
	public private(set) var result: Result<BridgeBackRequestResult<Bridge>, Error> = .failure(OperationError.notFinished)
	
	public init(request r: ImportBridgeOperationResultsRequest<Bridge>, importer i: any BackResultsImporter<Bridge>) {
		request = r
		importer = i
	}
	
	public override func main() {
		assert(request.operation.isFinished)
		do {
			let requestParsingUserInfo = request.bridge.userInfo(from: request.operation, currentUserInfo: request.userInfo)
			try throwIfCancelled()
			
			let metadata = try request.bridge.bridgeMetadata(from: request.operation, userInfo: requestParsingUserInfo)
			try throwIfCancelled()
			
			let remoteRepresentations = try request.bridge.remoteObjectRepresentations(from: request.operation, userInfo: requestParsingUserInfo)
			try throwIfCancelled()
			let dbRepresentationCount = try retrieveDbRepresentations(importer: importer, from: remoteRepresentations, expectedEntity: request.expectedEntity, userInfo: requestParsingUserInfo, bridge: request.bridge, shouldContinueHandler: { !self.isCancelled })
			try throwIfCancelled()
			
			guard dbRepresentationCount > 0 || request.importPreparationBlock != nil || request.importSuccessBlock != nil else {
				result = .success(BridgeBackRequestResult(metadata: metadata, returnedObjectIDsAndRelationships: [], asyncChanges: ChangesDescription()))
				return
			}
			
			try createAndPrepare(importer: importer, rootMetadata: metadata)
			
			/* I don't think NOT waiting is justified here.
			 * - We do not care about hogging the queue we're on because while the stuff we have to do in the context is not done,
			 *    the operation will not be finished and will hog the queue.
			 * - Not waiting would make us convert the operation to an asynchronous operation,
			 *    which is not a trivial task
			 *    and is not justified as per the previous point. */
			try request.db.performAndWait {
				try self.throwIfCancelled()
				
				do {
					guard try self.request.importPreparationBlock?() ?? true else {
						self.result = .failure(OperationError.cancelled)
						return
					}
					
					/* Once the import has started, it cannot be cancelled anymore. */
					let result = try unsafeImport(using: importer, in: self.request.db, updatingObject: self.request.updatedObjectId.flatMap{ try? self.request.db.unsafeRetrieveExistingObject(fromObjectID: $0) })
					try self.request.importSuccessBlock?(result.importResult)
					
					self.result = .success(result.bridgeBackRequestResult)
				} catch {
					self.request.importErrorBlock?(error)
					throw error
				}
			}
		} catch {
			result = .failure(error)
		}
	}
	
	public override var isAsynchronous: Bool {
		return false
	}
	
	private func throwIfCancelled() throws {
		guard !isCancelled else {throw OperationError.cancelled}
	}
	
	/* *********************
	   MARK: - Erasure Usage
	   *********************
	   This exists to workaround some Swift limitations when using any.*/
	
	private func retrieveDbRepresentations<Importer : BackResultsImporter>(importer: Importer, from remoteRepresentations: [Bridge.RemoteObjectRepresentation], expectedEntity entity: Bridge.Db.EntityDescription, userInfo: Bridge.UserInfo, bridge: Bridge, shouldContinueHandler: () -> Bool) throws -> Int where Importer.Bridge == Bridge {
		return try importer.retrieveDbRepresentations(from: remoteRepresentations, expectedEntity: entity, userInfo: userInfo, bridge: bridge, shouldContinueHandler: shouldContinueHandler)
	}
	
	private func createAndPrepare<Importer : BackResultsImporter>(importer: Importer, rootMetadata: Bridge.Metadata?) throws where Importer.Bridge == Bridge {
		return try importer.createAndPrepareDbImporter(rootMetadata: rootMetadata)
	}
	
	private func unsafeImport<Importer : BackResultsImporter>(using importer: Importer, in db: Bridge.Db, updatingObject updatedObject: Bridge.Db.Object?) throws -> ImportBridgeOperationResultsRequestOperation<Bridge>.DbRepresentationImporterResult where Importer.Bridge == Bridge {
		return try importer.unsafeImport(in: db, updatingObject: updatedObject)
	}
	
}
