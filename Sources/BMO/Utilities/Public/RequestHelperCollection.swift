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
 A collection of ``RequestHelperProtocol``s, conforming to ``RequestHelperProtocol``.
 
 If the collection is empty, this is equivalent to a ``DummyRequestHelper``. */
@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
public struct RequestHelperCollection<LocalDbContext : LocalDbContextProtocol, LocalDbObject : LocalDbObjectProtocol, Metadata> : RequestHelperProtocol {
	
	public let requestHelpers: [any RequestHelperProtocol<LocalDbContext, LocalDbObject, Metadata>]
	
	public init(requestHelpers: [any RequestHelperProtocol<LocalDbContext, LocalDbObject, Metadata>]) {
		self.requestHelpers = requestHelpers
	}
	
	/* *****************************************************************
	   MARK: Request Lifecycle Part 1: Local Request to Remote Operation
	   ***************************************************************** */
	
	public func onContext_localToRemote_prepareRemoteConversion(context: LocalDbContext, cancellationCheck throwIfCancelled: () throws -> Void) throws -> Bool {
		/* allSatisfy returns true if the collection is empty. */
		/* Must NOT be lazy! We want all the helpers to be called (if they do not throw).
		 * We stop (throw) at the first helper that throws: all the helpers will have a chance to clean themselves up in onContext_localToRemoteFailed. */
		return try requestHelpers
			.map{ try $0.onContext_localToRemote_prepareRemoteConversion(context: context, cancellationCheck: throwIfCancelled) }
			.allSatisfy{ $0 }
	}
	
	public func onContext_localToRemote_willGoRemote(context: LocalDbContext, cancellationCheck throwIfCancelled: () throws -> Void) throws {
		try requestHelpers.forEach{
			try $0.onContext_localToRemote_willGoRemote(context: context, cancellationCheck: throwIfCancelled)
		}
	}
	
	public func onContext_localToRemoteFailed(_ error: Error, context: LocalDbContext) {
		requestHelpers.forEach{ $0.onContext_localToRemoteFailed(error, context: context) }
	}
	
	public func onContext_localToRemoteSkipped(context: LocalDbContext) {
		requestHelpers.forEach{ $0.onContext_localToRemoteSkipped(context: context) }
	}
	
	/* ************************************************************
	   MARK: Request Lifecycle Part 2: Receiving the Remote Results
	   ************************************************************ */
	
	public func remoteFailed(_ error: Error) {
		requestHelpers.forEach{ $0.remoteFailed(error) }
	}
	
	/* *******************************************************************
	   MARK: Request Lifecycle Part 3: Local Db Representation to Local Db
	   ******************************************************************* */
	
	public func newContextForImportingRemoteResults() -> LocalDbContext?? {
		return requestHelpers.lazy.compactMap{ $0.newContextForImportingRemoteResults() }.first{ _ in true }
	}
	
	public func onContext_remoteToLocal_willImportRemoteResults(context: LocalDbContext, cancellationCheck throwIfCancelled: () throws -> Void) throws -> Bool {
		/* allSatisfy returns true if the collection is empty. */
		/* Must NOT be lazy! We want all the helpers to be called (if they do not throw).
		 * We stop (throw) at the first helper that throws: all the helpers will have a chance to clean themselves up in onContext_remoteToLocalFailed. */
		return try requestHelpers
			.map{ try $0.onContext_remoteToLocal_willImportRemoteResults(context: context, cancellationCheck: throwIfCancelled) }
			.allSatisfy{ $0 }
	}
	
	public func onContext_remoteToLocal_didImportRemoteResults(_ importChanges: LocalDbChanges<LocalDbObject, Metadata>, context: LocalDbContext, cancellationCheck throwIfCancelled: () throws -> Void) throws {
		try requestHelpers.forEach{
			try $0.onContext_remoteToLocal_didImportRemoteResults(importChanges, context: context, cancellationCheck: throwIfCancelled)
		}
	}
	
	public func onContext_remoteToLocalFailed(_ error: Error, context: LocalDbContext) {
		requestHelpers.forEach{ $0.onContext_remoteToLocalFailed(error, context: context) }
	}
	
}
