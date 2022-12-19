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



/* We’re not using RetryingOperation because it does not allow synchronous execution from start to startBaseOperation,
 *  and we want clients to be able to call start synchronously to guarantee being called on the context. */
public final class RequestOperation<Bridge : BridgeProtocol> : Operation, HasResult {
	
	public typealias Request = BMO.Request<Bridge.LocalDb, Bridge.RequestUserInfo>
	public typealias RequestResult = BMO.RequestResult<Bridge.RemoteDb.RemoteOperation, Bridge.LocalDb.DbObject, Bridge.Metadata>
	public typealias RequestError = BMO.RequestError<Bridge>
	
	public typealias RequestHelperCollection = RequestHelperCollectionForOldRuntimes<Bridge.LocalDb.DbObject, Bridge.Metadata>
	
	public var bridge: Bridge
	public var request: Request
	public var additionalHelpers: RequestHelperCollection
	
	public var remoteOperationQueue: OperationQueue
	public var computeOperationQueue: OperationQueue
	
	public var startedOnContext: Bool
	
	public var result: Result<RequestResult, Error> {
		lock.withLock{ _result }
	}
	
	public init(bridge: Bridge, request: Request, additionalHelpers: RequestHelperCollection = .init(), remoteOperationQueue: OperationQueue, computeOperationQueue: OperationQueue, startedOnContext: Bool = false) {
		self.bridge = bridge
		self.request = request
		self.additionalHelpers = additionalHelpers
		
		self.remoteOperationQueue = remoteOperationQueue
		self.computeOperationQueue = computeOperationQueue
		
		self.startedOnContext = startedOnContext
	}
	
	public override func start() {
		lock.withLock{ _result = .failure(OperationLifecycleError.operationInProgress) }
		continueOperation(switchToContext: !startedOnContext, onContext_beginOperation)
	}
	
	public override func cancel() {
		super.cancel()
		
		/* We cannot override a method from a generic objc class in an extension, so we call a dedicated method…
		 * Incidentally it’s better anyway because the cancel is near the start this way. */
		doCancellation()
	}
	
	public override var isAsynchronous: Bool {
		return true
	}
	
	public override var isExecuting: Bool {
		return isExecuting(with: result)
	}
	
	public override var isFinished: Bool {
		return isFinished(with: result)
	}
	
	/* *************
	   MARK: Private
	   ************* */
	
	private let lock = NSLock()
	private var _result: Result<RequestResult, Error> = .failure(OperationLifecycleError.operationNotStarted) {
		willSet {
			let oldFinished = isFinished(with: _result)
			let newFinished = isFinished(with: newValue)
			let oldExecuting = isExecuting(with: _result)
			let newExecuting = isExecuting(with: newValue)
			
			if oldExecuting != newExecuting {willChangeValue(forKey: "isExecuting")}
			if oldFinished  != newFinished  {willChangeValue(forKey: "isFinished")}
		}
		didSet {
			let oldFinished = isFinished(with: oldValue)
			let newFinished = isFinished(with: _result)
			let oldExecuting = isExecuting(with: oldValue)
			let newExecuting = isExecuting(with: _result)
			
			if oldFinished  != newFinished  {didChangeValue(forKey: "isFinished")}
			if oldExecuting != newExecuting {didChangeValue(forKey: "isExecuting")}
		}
	}
	
	private var remoteOperation: Bridge.RemoteDb.RemoteOperation?
	private var importOperation: LocalDbImportOperation<Bridge>?
	
	private func continueOperation(switchToContext: Bool = false, _ block: @escaping () throws -> Void) {
		if !switchToContext {
			do    {try block()}
			catch {finishOperation(.failure(error))}
		} else {
			request.localDb.context.performRW{
				self.continueOperation(switchToContext: false, block)
			}
		}
	}
	
	private func finishOperation(_ r: Result<RequestResult, Error>) {
		lock.withLock{
			assert(_result.failure as? OperationLifecycleError == .operationInProgress)
			_result = r
		}
	}
	
	private func isExecuting(with result: Result<RequestResult, Error>) -> Bool {
		return (result.failure as? OperationLifecycleError).flatMap{ $0 == .operationInProgress } ?? false
	}
	
	private func isFinished(with result: Result<RequestResult, Error>) -> Bool {
		return (result.failure as? OperationLifecycleError).flatMap{ $0 != .operationNotStarted && $0 != .operationInProgress } ?? true
	}
	
}



/* *******************
   MARK: - Actual Work
   ******************* */

private extension RequestOperation {
	
	func onContext_beginOperation() throws {
		/* TODO: This is nooooot very efficient, yeah… */
		let helper = RequestHelperCollection(bridge.requestHelper(for: request), additionalHelpers)
		
		/* Step 1: Check if retrieving the remote operation is needed. */
		try throwIfCancelled()
		guard try helper.onContext_requestNeedsRemote() !> RequestError.needsRemote(_:) else {
			return finishOperation(.success(.successNoop))
		}
		
		/* Step 2: Retrieve the remote operation. */
		try throwIfCancelled()
		let remoteOperationErrorHandler = { (_ error: Error) in
			helper.onContext_failedRemoteConversion(error)
			return RequestError.getRemoteOperation(error)
		}
		guard let (operation, userInfo) = try bridge.onContext_remoteOperation(for: request) !> remoteOperationErrorHandler else {
			return finishOperation(.success(.successNoop))
		}
		remoteOperation = operation
		let completionOperation = BlockOperation{ self.continueOperation{
			self.remoteOperation = nil
			try self.continueOperation(finishedRemoteOperation: operation, userInfo: userInfo, helper: helper)
		} }
		completionOperation.addDependency(operation)
		
		/* Step 3: Inform helper we’re launching the remote operation, and launch it. */
		try throwIfCancelled()
		try helper.onContext_willGoRemote() !> RequestError.willGoRemote(operation)
		remoteOperationQueue.addOperation(operation)
		computeOperationQueue.addOperation(completionOperation)
	}
	
	func continueOperation(finishedRemoteOperation: Bridge.RemoteDb.RemoteOperation, userInfo: Bridge.UserInfo, helper: RequestHelperCollection) throws {
		/* Step 4: Create the import operation and launch it. */
		try throwIfCancelled()
		let operation = LocalDbImportOperation(
			request: .finishedRemoteOperation(finishedRemoteOperation, userInfo: userInfo, bridge: bridge),
			localDb: request.localDb, helper: helper, importerFactory: bridge.importerForRemoteResults(localRepresentations:rootMetadata:uniquingIDsPerEntities:taskCancelled:)
		)
		importOperation = operation
		let completionOperation = BlockOperation{ self.continueOperation{
			self.importOperation = nil
			try self.continueOperation(finishedImportOperation: operation, finishedRemoteOperation: finishedRemoteOperation)
		} }
		completionOperation.addDependency(operation)
		
		computeOperationQueue.addOperations([operation, completionOperation], waitUntilFinished: false)
	}
	
	func continueOperation(finishedImportOperation: LocalDbImportOperation<Bridge>, finishedRemoteOperation: Bridge.RemoteDb.RemoteOperation) throws {
		/* Step 5: Retrieve import operation results and finish the operation. */
		/* We do NOT check whether we’re cancelled.
		 * If we are, the import operation will have been cancelled and we’ll get the error from there. */
		if let importResults = try finishedImportOperation.result.get() !> RequestError.addRemoteOperation(finishedRemoteOperation) {
			finishOperation(.success(.success(dbChanges: importResults, remoteOperation: finishedRemoteOperation)))
		} else {
			finishOperation(.success(.successNoopFromRemote(finishedRemoteOperation)))
		}
	}
	
}


private extension RequestOperation {
	
	/** Returns `true` if the operation was cancelled and the operation has been finished. */
	func throwIfCancelled() throws {
		guard !isCancelled else {
			throw OperationLifecycleError.cancelled
		}
	}
	
	func doCancellation() {
		remoteOperation?.cancel()
		importOperation?.cancel()
	}
	
}
