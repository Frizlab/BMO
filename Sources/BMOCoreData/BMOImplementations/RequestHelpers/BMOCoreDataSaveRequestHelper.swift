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

import CoreData
import Foundation
import os.log

import BMO



/* Have to be a class because we can change the `context` var.
 * Probably TODO: Give the context for each methods in the request helper protocol.
 * A very good reason: we, as a request helper, can say “I want a new context,” but nothing tells the new context will actually be used. */
public struct BMOCoreDataSaveRequestHelper<Metadata> : RequestHelperProtocol {
	
	public typealias LocalDbObject = NSManagedObject
	public typealias LocalDbContext = NSManagedObjectContext
	
	/**
	 The save workflow for the save operation.
	 
	 There are many other save workflow that could exist, but we believe these two should be enough for more than 99% of the cases.
	 We also want to avoid cases that would be useful for less than 1% of the cases.
	 
	 If you have a _very_ specific need you can always create your own save request helper. */
	public enum SaveWorkflow {
		
		/**
		 Nothing is done on the original context (the context should be discarded once the save request operation is started)
		  and the remote operation results are imported on another context (presumably the view context).
		 
		 This workflow is meant for save operation that do not need to be persisted on disk (“sync saves” where the user has to wait for the save to finish).
		 
		 For instance, when saving some profile info, if the save fail the user will be presented with a popup to inform him of the error.
		 There will be no need to save the modification on disk as the local view model of the view will still have the modifications in memory. */
		case doNothingChangeImportContext(NSManagedObjectContext)
		/**
		 The context is saved after computing the remote operation, but before launching it.
		 The remote operation results are imported on the same context (presumably the view context).
		 
		 This workflow is meant for save operation that should be persisted on disk (“async saves” where the user fires and forgets the save).
		 
		 For instance when sending a message we do not want to lose the message if the sending fails.
		 The message has to be persisted to disk, presumably with a bool indicating the message is being sent.
		 When the sending is over, whether it failed or succeeded the bool would be changed to reflect the new state.
		 
		 Changing the bool state is still up to the caller.
		 This can be done in another helper or directly in the completion of the request operation, or partly in the bridge, etc. */
		case saveBeforeGoingRemote
		
	}
	
	public let saveWorkflow: SaveWorkflow
	
	public init(saveWorkflow: SaveWorkflow) {
		self.saveWorkflow = saveWorkflow
	}
	
	/* *****************************************************************
	   MARK: Request Lifecycle Part 1: Local Request to Remote Operation
	   ***************************************************************** */
	
	public func onContext_localToRemote_prepareRemoteConversion(context: NSManagedObjectContext, cancellationCheck throwIfCancelled: () throws -> Void) throws -> Bool {
		context.processPendingChanges()
		return true
	}
	
	public func onContext_localToRemote_willGoRemote(context: NSManagedObjectContext, cancellationCheck throwIfCancelled: () throws -> Void) throws {
		switch saveWorkflow {
			case .saveBeforeGoingRemote:        try context.save()
			case .doNothingChangeImportContext: (/*nop*/)
		}
	}
	
	public func onContext_localToRemoteFailed(_ error: Error, context: NSManagedObjectContext) {
		switch saveWorkflow {
			case .doNothingChangeImportContext:
				(/* The context is assumed to be a throwable scratch pad, so we do nothing. */)
				
			case .saveBeforeGoingRemote:
				/* Here we want to keep a clean context.
				 * The goal of the saveBeforeGoingRemote workflow is to not lose the object that was created,
				 *  so we try and save the context when we have a failure.
				 * We rollback if the save fails in order to have our clean context! */
				if let error = context.saveOrRollback() {
					if #available(macOS 11.0, *) {Logger.saveRequestHelper.warning("Failed saving the context after local to remote conversion failed: \(error).")}
					else                         {os_log("Failed saving the context after local to remote conversion failed: %@.", log: .saveRequestHelper, type: .error, String(describing: error))}
				}
		}
	}
	
	/* ************************************************************
	   MARK: Request Lifecycle Part 2: Receiving the Remote Results
	   ************************************************************ */
	
	public func remoteFailed(_ error: Error) {
		/* nop: either we’re in the “do nothing” workflow in which case we do nothing, or the save/rollback happened before the remote operation was started.
		 * Of course, when (if) we implement saveAfterBackReturns we’ll have to rollback here if this save workflow is chosen. */
	}
	
	/* *******************************************************************
	   MARK: Request Lifecycle Part 3: Local Db Representation to Local Db
	   ******************************************************************* */
	
	public func newContextForImportingRemoteResults() -> NSManagedObjectContext?? {
		switch saveWorkflow {
			case .saveBeforeGoingRemote:                        return nil
			case .doNothingChangeImportContext(let newContext): return newContext
		}
	}
	
	public func onContext_remoteToLocal_willImportRemoteResults(context: NSManagedObjectContext, cancellationCheck throwIfCancelled: () throws -> Void) throws -> Bool {
		assert(!context.hasPersistentChanges)
		return true
	}
	
	public func onContext_remoteToLocal_didImportRemoteResults(_ importChanges: LocalDbChanges<NSManagedObject, Metadata>, context: NSManagedObjectContext, cancellationCheck throwIfCancelled: () throws -> Void) throws {
		try context.save()
	}
	
	public func onContext_remoteToLocalFailed(_ error: Error, context: NSManagedObjectContext) {
		context.rollback()
	}
	
}
