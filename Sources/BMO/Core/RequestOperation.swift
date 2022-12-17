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
	
	public typealias Request = BMO.Request<Bridge.LocalDb.DbRequest, Bridge.RequestUserInfo>
	public typealias RequestResult = BMO.RequestResult<Bridge.RemoteDb.RemoteOperation, Bridge.LocalDb.DbObject, Bridge.Metadata>
	
	public let bridge: Bridge
	public let request: Request
	
	public var willBeStartedOnContext: Bool
	
	public var result: Result<RequestResult, Error> {
		lock.withLock{ _result }
	}
	
	init(bridge: Bridge, request: Request, willBeStartedOnContext: Bool = false) {
		self.bridge = bridge
		self.request = request
		self.willBeStartedOnContext = willBeStartedOnContext
	}
	
	public override func start() {
		do    {try startThrowing()}
		catch {finishOperation(.failure(error))}
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
	
	func startThrowing() throws {
		try throwIfCancelled()
		let helper = bridge.requestHelper(for: request)
		guard try helper.onContext_requestNeedsRemote() else {
			return finishOperation(.success(.successNoop))
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
#warning("TODO")
	}
	
}
