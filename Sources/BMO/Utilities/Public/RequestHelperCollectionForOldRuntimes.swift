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



/**
 A temporary workaround for replacing ``RequestHelperCollection`` when runtime is too old.
 Another workaround would have been to erase the protocol fully and use an array of erased objects. */
public struct RequestHelperCollectionForOldRuntimes<LocalDbContext : LocalDbContextProtocol, LocalDbObject : LocalDbObjectProtocol, Metadata> : RequestHelperProtocol {
	
	public let requestHelper1: (any RequestHelperProtocol<LocalDbContext, LocalDbObject, Metadata>)?
	public let requestHelper2: (any RequestHelperProtocol<LocalDbContext, LocalDbObject, Metadata>)?
	public let requestHelper3: (any RequestHelperProtocol<LocalDbContext, LocalDbObject, Metadata>)?
	
	public init(
		_ requestHelper1: (any RequestHelperProtocol<LocalDbContext, LocalDbObject, Metadata>)? = nil,
		_ requestHelper2: (any RequestHelperProtocol<LocalDbContext, LocalDbObject, Metadata>)? = nil,
		_ requestHelper3: (any RequestHelperProtocol<LocalDbContext, LocalDbObject, Metadata>)? = nil
	) {
		self.requestHelper1 = requestHelper1
		self.requestHelper2 = requestHelper2
		self.requestHelper3 = requestHelper3
	}
	
	/* *****************************************************************
	   MARK: Request Lifecycle Part 1: Local Request to Remote Operation
	   ***************************************************************** */
	
	public func onContext_localToRemote_prepareRemoteConversion(cancellationCheck throwIfCancelled: () throws -> Void) throws -> Bool {
		return [
			try requestHelper1?.onContext_localToRemote_prepareRemoteConversion(cancellationCheck: throwIfCancelled) ?? true,
			try requestHelper2?.onContext_localToRemote_prepareRemoteConversion(cancellationCheck: throwIfCancelled) ?? true,
			try requestHelper3?.onContext_localToRemote_prepareRemoteConversion(cancellationCheck: throwIfCancelled) ?? true
		].allSatisfy{ $0 }
	}
	
	public func onContext_localToRemote_willGoRemote(cancellationCheck throwIfCancelled: () throws -> Void) throws {
		try requestHelper1?.onContext_localToRemote_willGoRemote(cancellationCheck: throwIfCancelled)
		try requestHelper2?.onContext_localToRemote_willGoRemote(cancellationCheck: throwIfCancelled)
		try requestHelper3?.onContext_localToRemote_willGoRemote(cancellationCheck: throwIfCancelled)
	}
	
	public func onContext_localToRemoteFailed(_ error: Error) {
		requestHelper1?.onContext_localToRemoteFailed(error)
		requestHelper2?.onContext_localToRemoteFailed(error)
		requestHelper3?.onContext_localToRemoteFailed(error)
	}
	
	/* ************************************************************
	   MARK: Request Lifecycle Part 2: Receiving the Remote Results
	   ************************************************************ */
	
	public func remoteFailed(_ error: Error) {
		requestHelper1?.remoteFailed(error)
		requestHelper2?.remoteFailed(error)
		requestHelper3?.remoteFailed(error)
	}
	
	/* *******************************************************************
	   MARK: Request Lifecycle Part 3: Local Db Representation to Local Db
	   ******************************************************************* */
	
	public func newContextForImportingRemoteResults() -> LocalDbContext?? {
		return (
			requestHelper1?.newContextForImportingRemoteResults() ??
			requestHelper2?.newContextForImportingRemoteResults() ??
			requestHelper3?.newContextForImportingRemoteResults()
		)
	}
	
	public func onContext_remoteToLocal_willImportRemoteResults(cancellationCheck throwIfCancelled: () throws -> Void) throws -> Bool {
		return [
			try requestHelper1?.onContext_remoteToLocal_willImportRemoteResults(cancellationCheck: throwIfCancelled) ?? true,
			try requestHelper2?.onContext_remoteToLocal_willImportRemoteResults(cancellationCheck: throwIfCancelled) ?? true,
			try requestHelper3?.onContext_remoteToLocal_willImportRemoteResults(cancellationCheck: throwIfCancelled) ?? true
		].allSatisfy{ $0 }
	}
	
	public func onContext_remoteToLocal_didImportRemoteResults(_ importChanges: LocalDbChanges<LocalDbObject, Metadata>, cancellationCheck throwIfCancelled: () throws -> Void) throws {
		try requestHelper1?.onContext_remoteToLocal_didImportRemoteResults(importChanges, cancellationCheck: throwIfCancelled)
		try requestHelper2?.onContext_remoteToLocal_didImportRemoteResults(importChanges, cancellationCheck: throwIfCancelled)
		try requestHelper3?.onContext_remoteToLocal_didImportRemoteResults(importChanges, cancellationCheck: throwIfCancelled)
	}
	
	public func onContext_remoteToLocalFailed(_ error: Error) {
		requestHelper1?.onContext_remoteToLocalFailed(error)
		requestHelper2?.onContext_remoteToLocalFailed(error)
		requestHelper3?.onContext_remoteToLocalFailed(error)
	}
	
}
