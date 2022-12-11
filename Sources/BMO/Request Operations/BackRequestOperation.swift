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



public final class BackRequestOperation<Request : BackRequest, Bridge : BridgeProtocol> : Operation
	where Bridge.Db == Request.Db, Bridge.AdditionalRequestInfo == Request.AdditionalRequestInfo
{
	
	public let bridge: Bridge
	public let request: Request
	public let importer: (any BackResultsImporter<Bridge>)?
	
	public let backOperationQueue: OperationQueue
	public let parseOperationQueue: OperationQueue
	
	public private(set) var result: Result<BackRequestResult<Request, Bridge>, Error> = .failure(OperationError.notFinished)
	
	public init(request r: Request, bridge b: Bridge, importer i: (any BackResultsImporter<Bridge>)?, backOperationQueue bq: OperationQueue, parseOperationQueue pq: OperationQueue, requestManager: RequestManager?) {
		bridge = b
		request = r
		importer = i
		
		backOperationQueue = bq
		parseOperationQueue = pq
		resultsProcessingQueue = OperationQueue(); resultsProcessingQueue.maxConcurrentOperationCount = 1
		
		super.init()
		
		if let requestManager = requestManager {
			globalCancellationObserver = NotificationCenter.default.addObserver(forName: .BMORequestManagerCancelAllBackRequestOperations, object: requestManager, queue: nil) { [weak self] n in
				self?.cancel()
			}
		}
	}
	
	deinit {
		if let o = globalCancellationObserver {NotificationCenter.default.removeObserver(o)} /* Shouldn't really be needed... */
	}
	
	/**
	 If you’re already in the request context, you can call this before starting the request.
	 It is actually the only way to retrieve the operations for the request synchronously.
	 
	 This will avoid a context jump when actually starting the operation.
	 (You can start it right after calling this method if you want.)
	 
	 Also, sometimes it is needed to have a known context state to compute the operations to execute for the given request,
	  which can only be achieved by calling the preparation synchronously. */
	public func unsafePrepareStart() throws {
		try unsafePrepareStart(withSafePartResults: nil)
	}
	
	public override func start() {
		assert(state == .inited)
		guard !isCancelled else {result = .failure(OperationError.cancelled); state = .finished; return}
		
		state = .running
		if let bridgeOperations = bridgeOperations {
			launchOperations(bridgeOperations)
		} else {
			do {
				let safePrepareResults = try prepareStartSafePart()
				if let requestParts = safePrepareResults.requestParts, requestParts.count == 0 {
					assert(safePrepareResults.enteredBridge)
					launchOperations([])
					return
				}
				request.db.perform {
					do {
						guard !self.isCancelled else {throw OperationError.cancelled}
						self.launchOperations(try self.unsafePrepareStart(withSafePartResults: safePrepareResults))
					} catch {
						self.result = .failure(error)
						self.state = .finished
					}
				}
			} catch {
				self.result = .failure(error)
				self.state = .finished
			}
		}
	}
	
	public override func cancel() {
		cancellationSemaphore.wait(); defer {cancellationSemaphore.signal()}
		super.cancel()
		
		bridgeOperations?.forEach{ $0.parseOperation?.cancel(); $0.backOperation.cancel(); /* NOT cancelling the results processing operation. */ }
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private var globalCancellationObserver: NSObjectProtocol? {
		willSet {
			if let o = globalCancellationObserver {NotificationCenter.default.removeObserver(o)}
		}
	}
	
	private enum RequestOperationState {
		
		case inited
		case running
		case finished
		
	}
	
	private func launchOperations(_ operations: [BridgeOperation]) {
		cancellationSemaphore.wait(); defer {cancellationSemaphore.signal()}
		guard !isCancelled else {result = .failure(OperationError.cancelled); state = .finished; return}
		
		let completionOperation = BlockOperation{ [weak self] in
			guard let strongSelf = self else {return}
			strongSelf.result = .success(BackRequestResult(results: strongSelf.resultsBuilding))
			strongSelf.state = .finished
		}
		/* The completion operation will be called only when ALL dependencies are finished.
		 * Even cancelled dependencies are waited on. */
		operations.forEach{ completionOperation.addDependency($0.resultsProcessingOperation) }
		
		backOperationQueue.addOperations(operations.map{ $0.backOperation }, waitUntilFinished: false)
		parseOperationQueue.addOperations(operations.compactMap{ $0.parseOperation }, waitUntilFinished: false)
		resultsProcessingQueue.addOperations(operations.map{ $0.resultsProcessingOperation }, waitUntilFinished: false)
		resultsProcessingQueue.addOperation(completionOperation)
	}
	
	private func prepareStartSafePart() throws -> SafePartStartPreparationResults {
		guard !request.needsEnteringBridgeOnContext else {return (false, nil)}
		guard try request.enterBridge() else {return (true, [:])}
		
		guard !request.needsRetrievingBackRequestPartsOnContext else {return (true, nil)}
		return (true, try request.backRequestParts())
	}
	
	@discardableResult
	private func unsafePrepareStart(withSafePartResults safePart: SafePartStartPreparationResults?) throws -> [BridgeOperation] {
		do {
			if let bridgeOperations = bridgeOperations {return bridgeOperations}
			guard try (safePart?.enteredBridge ?? false) || request.enterBridge() else {bridgeOperations = []; return []}
			
			var operations = [BridgeOperation]()
			
			for (dbRequestID, dbRequestPart) in try safePart?.requestParts ?? request.backRequestParts() {
				guard !isCancelled else {throw OperationError.cancelled}
				guard let operation = try bridgeOperation(forDbRequestPart: dbRequestPart, withID: dbRequestID) else {continue}
				operations.append(operation)
			}
			
			guard try request.leaveBridge() else {
				bridgeOperations = []
				return []
			}
			
			bridgeOperations = operations
			return operations
		} catch {
			request.processBridgeError(error)
			throw error
		}
	}
	
	private func bridgeOperation(forDbRequestPart part: BackRequestPart<Request.Db.Object, Request.Db.FetchRequest, Request.AdditionalRequestInfo>, withID requestPartID: Request.RequestPartID) throws -> BridgeOperation? {
		var userInfo = bridge.createUserInfoObject()
		
		/* Retrieve the back operation part of the bridge operation. */
		let expectedEntity: Bridge.Db.EntityDescription
		let backOperationO: Bridge.BackOperation?
		let updatedObject: Bridge.Db.Object?
		switch part {
			case .fetch(let fetchRequest, let additionalInfo): updatedObject = nil;    expectedEntity = bridge.expectedResultEntity(for: fetchRequest, additionalInfo: additionalInfo); backOperationO = try bridge.backOperation(forFetch:    fetchRequest, additionalInfo: additionalInfo, userInfo: &userInfo)
			case .insert(let object, let additionalInfo):      updatedObject = object; expectedEntity = bridge.expectedResultEntity(for: object);                                       backOperationO = try bridge.backOperation(forInserted: object,       additionalInfo: additionalInfo, userInfo: &userInfo)
			case .update(let object, let additionalInfo):      updatedObject = object; expectedEntity = bridge.expectedResultEntity(for: object);                                       backOperationO = try bridge.backOperation(forUpdated:  object,       additionalInfo: additionalInfo, userInfo: &userInfo)
			case .delete(let object, let additionalInfo):      updatedObject = object; expectedEntity = bridge.expectedResultEntity(for: object);                                       backOperationO = try bridge.backOperation(forDeleted:  object,       additionalInfo: additionalInfo, userInfo: &userInfo)
		}
		
		guard let backOperation = backOperationO else {
			return nil
		}
		
		let parseOperation: Operation?
		let resultsProcessingOperation: Operation
		if let db = request.dbForImportingResults(ofRequestPart: part, withID: requestPartID) {
			let resultsImportRequest = ImportBridgeOperationResultsRequest(
				db: db, bridge: bridge, operation: backOperation, expectedEntity: expectedEntity,
				updatedObjectID: updatedObject.flatMap{ self.request.db.unsafeObjectID(forObject: $0) },
				userInfo: userInfo,
				importPreparationBlock: { try self.request.prepareResultsImport(ofRequestPart: part, withID: requestPartID, inDb: db) },
				importSuccessBlock: { try self.request.endResultsImport(ofRequestPart: part, withID: requestPartID, inDb: db, importResults: $0) },
				importErrorBlock: { self.request.processResultsImportError(ofRequestPart: part, withID: requestPartID, inDb: db, error: $0) }
			)
			/* Maybe think about it a little more, but it seems normal that if there is no importer, we should crash.
			 * Another solution would be to gracefully simply not import the results…
			 * (Check if importer is nil in if above.) */
			let importOperation = ImportBridgeOperationResultsRequestOperation(request: resultsImportRequest, importer: importer!)
			importOperation.addDependency(backOperation)
			parseOperation = importOperation
			resultsProcessingOperation = BlockOperation{ self.resultsBuilding[requestPartID] = importOperation.result }
			resultsProcessingOperation.addDependency(importOperation)
		} else {
			parseOperation = nil
			resultsProcessingOperation = BlockOperation{
				self.resultsBuilding[requestPartID] =
					self.bridge.error(from: backOperation).map{ .failure($0) } ??
						.success(BridgeBackRequestResult(metadata: nil, returnedObjectIDsAndRelationships: [], asyncChanges: ChangesDescription()))
			}
			resultsProcessingOperation.addDependency(backOperation)
		}
		
		return (backOperation: backOperation, parseOperation: parseOperation, resultsProcessingOperation: resultsProcessingOperation)
	}
	
	private typealias SafePartStartPreparationResults = (enteredBridge: Bool, requestParts: [Request.RequestPartID: BackRequestPart<Request.Db.Object, Request.Db.FetchRequest, Request.AdditionalRequestInfo>]?)
	
	private typealias BridgeOperation = (backOperation: Operation, parseOperation: Operation?, resultsProcessingOperation: Operation)
	
	private let cancellationSemaphore = DispatchSemaphore(value: 1)
	
	private var bridgeOperations: [BridgeOperation]?
	private let resultsProcessingQueue: OperationQueue /* A serial queue */
	private var resultsBuilding = Dictionary<Request.RequestPartID, Result<BridgeBackRequestResult<Bridge>, Error>>()
	
	private var state = RequestOperationState.inited {
		willSet(newState) {
			let newStateExecuting = (newState == .running)
			let oldStateExecuting = (state == .running)
			let newStateFinished = (newState == .finished)
			let oldStateFinished = (state == .finished)
			
			self.willChangeValue(forKey: "state")
			if newStateExecuting != oldStateExecuting {self.willChangeValue(forKey: "isExecuting")}
			if newStateFinished  != oldStateFinished  {self.willChangeValue(forKey: "isFinished")}
		}
		didSet(oldState) {
			let newStateExecuting = (state == .running)
			let oldStateExecuting = (oldState == .running)
			let newStateFinished = (state == .finished)
			let oldStateFinished = (oldState == .finished)
			
			/* Let's cleanup the bridge operations to avoid a retain cycle. */
			if state == .finished {bridgeOperations?.removeAll()}
			
			if newStateFinished  != oldStateFinished  {self.didChangeValue(forKey: "isFinished")}
			if newStateExecuting != oldStateExecuting {self.didChangeValue(forKey: "isExecuting")}
			self.didChangeValue(forKey: "state")
		}
	}
	
	public final override var isExecuting: Bool {
		return state == .running
	}
	
	public final override var isFinished: Bool {
		return state == .finished
	}
	
	public final override var isAsynchronous: Bool {
		return true
	}
	
}
