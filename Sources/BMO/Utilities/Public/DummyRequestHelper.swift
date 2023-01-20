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



public struct DummyRequestHelper<LocalDbContext : LocalDbContextProtocol, LocalDbObject : LocalDbObjectProtocol, Metadata> : RequestHelperProtocol {
	
	/* *****************************************************************
	   MARK: Request Lifecycle Part 1: Local Request to Remote Operation
	   ***************************************************************** */
	
	public func onContext_localToRemote_prepareRemoteConversion(context: LocalDbContext, cancellationCheck throwIfCancelled: () throws -> Void) throws -> Bool {
		return true
	}
	
	public func onContext_localToRemote_willGoRemote(context: LocalDbContext, cancellationCheck throwIfCancelled: () throws -> Void) throws {
	}
	
	public func onContext_localToRemoteFailed(_ error: Error, context: LocalDbContext) {
	}
	
	/* ************************************************************
	   MARK: Request Lifecycle Part 2: Receiving the Remote Results
	   ************************************************************ */
	
	public func remoteFailed(_ error: Error) {
	}
	
	/* *******************************************************************
	   MARK: Request Lifecycle Part 3: Local Db Representation to Local Db
	   ******************************************************************* */
	
	public func newContextForImportingRemoteResults() -> LocalDbContext?? {
		return nil
	}
	
	public func onContext_remoteToLocal_willImportRemoteResults(context: LocalDbContext, cancellationCheck throwIfCancelled: () throws -> Void) throws -> Bool {
		return true
	}
	public func onContext_remoteToLocal_didImportRemoteResults(_ importChanges: LocalDbChanges<LocalDbObject, Metadata>, context: LocalDbContext, cancellationCheck throwIfCancelled: () throws -> Void) throws {
	}
	
	public func onContext_remoteToLocalFailed(_ error: Error, context: LocalDbContext) {
	}
	
}
