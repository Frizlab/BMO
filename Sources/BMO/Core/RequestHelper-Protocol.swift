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



public protocol RequestHelperProtocol<LocalDbContext, LocalDbObject, Metadata> {
	
	associatedtype LocalDbContext : LocalDbContextProtocol
	associatedtype LocalDbObject : LocalDbObjectProtocol
	associatedtype Metadata
	
	/* *****************************************************************
	   MARK: Request Lifecycle Part 1: Local Request to Remote Operation
	   *****************************************************************
	   The three methods that follow are guaranteed to all be called within the same “perform” block (if called at all). */
	
	/**
	 Prepare the remote conversion, returns whether the conversion is required.
	 
	 Let’s see an example of where it would make sense to return `false` (from our `BMOCoreData` implementation):
	  ``BMOCoreDataFetchRequestHelper`` allows setting a fetch type.
	 
	 If the fetch type is ``BMOCoreDataFetchRequestHelper/FetchType/onlyIfNoLocalResults``,
	 this helper method will check whether the fetch request has local results already.
	 
	 If it does, there are no needs for a remote operation and the method will return `false`. */
	func onContext_localToRemote_prepareRemoteConversion(context: LocalDbContext, cancellationCheck throwIfCancelled: () throws -> Void) throws -> Bool
	func onContext_localToRemote_willGoRemote(           context: LocalDbContext, cancellationCheck throwIfCancelled: () throws -> Void) throws
	/**
	 Called if any part of the local to remote conversion fails.
	 
	 - Important: Can be called even _before_ ``onContext_localToRemote_prepareRemoteConversion(cancellationCheck:)`` is called (in which case it will obviously not be called). */
	func onContext_localToRemoteFailed(_ error: Error, context: LocalDbContext)
	
	/* ************************************************************
	   MARK: Request Lifecycle Part 2: Receiving the Remote Results
	   ************************************************************ */
	
	/**
	 Called if the remote operation fails, including the conversion of the remote results to a local db representation.
	 
	 This method is NOT called on the context.
	 You’re responsible for switching to the db context if you need it.
	 
	 This is a design decision, to avoid a useless hop to the context if no actions are needed. */
	func remoteFailed(_ error: Error)
	
	/* *******************************************************************
	   MARK: Request Lifecycle Part 3: Local Db Representation to Local Db
	   *******************************************************************
	   The three onContext methods that follow are guaranteed to all be called within the same “perform” block (if called at all). */
	
	/**
	 Get a new context for importing the results from the remote operation.
	 
	 If this returns nil the _same_ context is used as the original one (the import is **not** cancelled).
	 If this returns .some(nil), the import is skipped. */
	func newContextForImportingRemoteResults() -> LocalDbContext??
	
	/**
	 Informs the helper the importer _will_ start importing the local db results.
	 
	 If this method returns `false`, the import will not happen but the ``LocalDbImportOperation`` will not fail.
	 If this method throws, the import will not happen and the ``LocalDbImportOperation`` will fail. */
	func onContext_remoteToLocal_willImportRemoteResults(                                                         context: LocalDbContext, cancellationCheck throwIfCancelled: () throws -> Void) throws -> Bool
	func onContext_remoteToLocal_didImportRemoteResults(_ importChanges: LocalDbChanges<LocalDbObject, Metadata>, context: LocalDbContext, cancellationCheck throwIfCancelled: () throws -> Void) throws
	/**
	 Called if any part of the import operation fails.
	 
	 - Important: Can be called even _before_ ``onContext_remoteToLocal_willImportRemoteResults(cancellationCheck:)`` is called (in which case it will obviously not be called). */
	func onContext_remoteToLocalFailed(_ error: Error, context: LocalDbContext)
	
}
