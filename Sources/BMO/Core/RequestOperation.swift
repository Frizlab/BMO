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



/* We’re not using RetryingOperation because it does not allow synchronous execution from start to startBaseOperation,
 *  and we want clients to be able to call start synchronously to guarantee being called on the context. */
public final class RequestOperation<Bridge : BridgeProtocol> : Operation, @unchecked Sendable {
	
	public typealias Request = BMO.Request<Bridge.LocalDb, Bridge.RequestUserInfo>
	public typealias RequestResult = BMO.RequestResult<Bridge.RemoteDb.RemoteOperation, Bridge.LocalDb.DbObject, Bridge.Metadata>
	public typealias RequestError = BMO.RequestError<Bridge>
	
	public typealias RequestHelperCollection = RequestHelperCollectionForOldRuntimes<Bridge.LocalDb.DbContext, Bridge.LocalDb.DbObject, Bridge.Metadata>
	
	public let bridge: Bridge
	public let request: Request
	public let helper: RequestHelperCollection /* When Swift’s runtime allows it, this will be an “any RequestHelperProtocol<Bridge.LocalDb.DbObject, Bridge.Metadata>” instead. */
	
	public let remoteOperationQueue: OperationQueue
	public let computeOperationQueue: OperationQueue
	
	public let startedOnContext: Bool
	
	public var result: Result<RequestResult, RequestError> {
		lock.withLock{ _result }
	}
	
	/**
	 Initializes a RequestOperation.
	 
	 - parameter additionalHelpers: A collection of helpers called in addition of the bridge helper.
	 The additional helpers are called _before_ the bridge helper. */
	public init(bridge: Bridge, request: Request, additionalHelpers: RequestHelperCollection = .init(), remoteOperationQueue: OperationQueue, computeOperationQueue: OperationQueue, startedOnContext: Bool = false) {
		self.bridge = bridge
		self.request = request
		/* TODO (or not): This is nooooot very efficient (but it’s not slow either…) */
		self.helper = RequestHelperCollection(additionalHelpers, bridge.requestHelper(for: request))
		
		self.remoteOperationQueue = remoteOperationQueue
		self.computeOperationQueue = computeOperationQueue
		
		self.startedOnContext = startedOnContext
	}
	
	public override func start() {
		lock.withLock{ _result = .failure(RequestError(failureStep: .none, lifecycleError: .inProgress)) }
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
	
	/* We use a recursive lock because isExecuting is called from within the didChangeValue call…
	 * Another solution I think would be to use another lock and have separate variables for isExecuting and isFinished, modified within the separate lock. */
	private let lock = NSRecursiveLock()
	private var _result: Result<RequestResult, RequestError> = .failure(RequestError(failureStep: .none, lifecycleError: .notStarted)) {
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
	
	private func continueOperation(switchToContext: Bool = false, _ block: @escaping () -> RequestError?) {
		if !switchToContext {
			if let err = block() {
				finishOperation(.failure(err))
			}
		} else {
			request.localDbContext.performRW{
				self.continueOperation(switchToContext: false, block)
			}
		}
	}
	
	private func finishOperation(_ r: Result<RequestResult, RequestError>) {
		lock.withLock{
			assert(_result.failure?.underlyingError as? OperationLifecycleError == .inProgress)
			assert(!(r.failure?.underlyingError is OperationLifecycleError) ||
					 (r.failure?.underlyingError as? OperationLifecycleError == .cancelled))
			_result = r
		}
	}
	
	private func isExecuting(with result: Result<RequestResult, RequestError>) -> Bool {
		return (result.failure?.underlyingError as? OperationLifecycleError).flatMap{ $0 == .inProgress } ?? false
	}
	
	private func isFinished(with result: Result<RequestResult, RequestError>) -> Bool {
		return (result.failure?.underlyingError as? OperationLifecycleError).flatMap{ $0 != .notStarted && $0 != .inProgress } ?? true
	}
	
}



/* *******************
   MARK: - Actual Work
   ******************* */

private extension RequestOperation {
	
	func onContext_beginOperation() -> RequestError? {
		var step: RequestError.FailureStep = .none
		do {
			/* Step 1: Check if retrieving the remote operation is needed. */
			try throwIfCancelled()
			step = .helper_prepareRemoteConversion
			guard try helper.onContext_localToRemote_prepareRemoteConversion(context: request.localDbContext, cancellationCheck: throwIfCancelled) else {
				helper.onContext_localToRemoteSkipped(context: request.localDbContext)
				finishOperation(.success(.successNoop))
				return nil
			}
			
			/* Step 2: Retrieve the remote operation. */
			try throwIfCancelled()
			step = .bridge_getRemoteOperation
			guard let (operation, userInfo) = try bridge.onContext_remoteOperation(for: request) else {
				helper.onContext_localToRemoteSkipped(context: request.localDbContext)
				finishOperation(.success(.successNoop))
				return nil
			}
			remoteOperation = operation
			let completionOperation = BlockOperation{ self.continueOperation{
				self.remoteOperation = nil
				return self.continueOperation(finishedRemoteOperation: operation, userInfo: userInfo)
			} }
			completionOperation.addDependency(operation)
			
			/* Step 3: Inform helper we’re launching the remote operation, and launch it. */
			try throwIfCancelled()
			step = .helper_willGoRemote
			try helper.onContext_localToRemote_willGoRemote(context: request.localDbContext, cancellationCheck: throwIfCancelled)
			remoteOperationQueue.addOperation(operation)
			computeOperationQueue.addOperation(completionOperation)
			
			/* Finally we report everything went well to the caller. */
			return nil
		} catch {
			/* Let’s inform the helper(s) there was an issue. */
			helper.onContext_localToRemoteFailed(error, context: request.localDbContext)
			/* Then wrap the error in a RequestError and return it. */
			return RequestError(failureStep: step, checkedUnderlyingError: error)
		}
	}
	
	func continueOperation(finishedRemoteOperation: Bridge.RemoteDb.RemoteOperation, userInfo: Bridge.UserInfo) -> RequestError? {
		/* Step 4: Create the import operation and launch it. */
		let step: RequestError.FailureStep = .none
		do {
			try throwIfCancelled()
			let operation = LocalDbImportOperation(
				request: .finishedRemoteOperation(finishedRemoteOperation, userInfo: userInfo, bridge: bridge),
				localDb: request.localDb, localDbContextOverride: request.localDbContextOverwrite,
				helper: helper, importerFactory: bridge.importerForRemoteResults(localRepresentations:rootMetadata:uniquingIDsPerEntities:updatedObjectIDsPerEntities:cancellationCheck:)
			)
			importOperation = operation
			let completionOperation = BlockOperation{ self.continueOperation{
				self.importOperation = nil
				return self.continueOperation(finishedImportOperation: operation, finishedRemoteOperation: finishedRemoteOperation)
			} }
			completionOperation.addDependency(operation)
			
			computeOperationQueue.addOperations([operation, completionOperation], waitUntilFinished: false)
			return nil
		} catch {
			helper.remoteFailed(error)
			let step = (error is OperationLifecycleError ? .none : step)
			return RequestError(failureStep: step, checkedUnderlyingError: error)
		}
	}
	
	func continueOperation(finishedImportOperation: LocalDbImportOperation<Bridge>, finishedRemoteOperation: Bridge.RemoteDb.RemoteOperation) -> RequestError? {
		/* Step 5: Retrieve import operation results and finish the operation. */
		/* We do NOT check whether we’re cancelled.
		 * If we are, the import operation will have been cancelled and we’ll get the error from there. */
		switch finishedImportOperation.result {
			case .failure(let error):          return error
			case .success(nil):                finishOperation(.success(.successNoopFromRemote(finishedRemoteOperation)))
			case .success(let importResults?): finishOperation(.success(.success(dbChanges: importResults, remoteOperation: finishedRemoteOperation)))
		}
		return nil
	}
	
}


private extension RequestOperation {
	
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
