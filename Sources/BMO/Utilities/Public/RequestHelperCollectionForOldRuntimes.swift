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
public struct RequestHelperCollectionForOldRuntimes<LocalDbObject : LocalDbObjectProtocol, Metadata> : RequestHelperProtocol {
	
	public let requestHelper1: (any RequestHelperProtocol<LocalDbObject, Metadata>)?
	public let requestHelper2: (any RequestHelperProtocol<LocalDbObject, Metadata>)?
	public let requestHelper3: (any RequestHelperProtocol<LocalDbObject, Metadata>)?
	
	public init(
		_ requestHelper1: (any RequestHelperProtocol<LocalDbObject, Metadata>)? = nil,
		_ requestHelper2: (any RequestHelperProtocol<LocalDbObject, Metadata>)? = nil,
		_ requestHelper3: (any RequestHelperProtocol<LocalDbObject, Metadata>)? = nil
	) {
		self.requestHelper1 = requestHelper1
		self.requestHelper2 = requestHelper2
		self.requestHelper3 = requestHelper3
	}
	
	public func onContext_requestNeedsRemote() throws -> Bool {
		if try requestHelper1?.onContext_requestNeedsRemote() ?? false {return true}
		if try requestHelper2?.onContext_requestNeedsRemote() ?? false {return true}
		if try requestHelper3?.onContext_requestNeedsRemote() ?? false {return true}
		
		switch (requestHelper1, requestHelper2, requestHelper3) {
			case (nil, nil, nil): return true
			default:              return false
		}
	}
	
	public func onContext_failedRemoteConversion(_ error: Error) {
		requestHelper1?.onContext_failedRemoteConversion(error)
		requestHelper2?.onContext_failedRemoteConversion(error)
		requestHelper3?.onContext_failedRemoteConversion(error)
	}
	
	public func onContext_willGoRemote() throws {
		let errors = [
			Result{ try requestHelper1?.onContext_willGoRemote() }.failure,
			Result{ try requestHelper1?.onContext_willGoRemote() }.failure,
			Result{ try requestHelper1?.onContext_willGoRemote() }.failure
		].compactMap{ $0 }
		guard errors.isEmpty else {
			throw ErrorCollection(errors)
		}
	}
	
	public func onContext_willImportRemoteResults() throws -> Bool {
		let results = [
			Result{ try requestHelper1?.onContext_willImportRemoteResults() },
			Result{ try requestHelper1?.onContext_willImportRemoteResults() },
			Result{ try requestHelper1?.onContext_willImportRemoteResults() }
		]
		let errors = results.compactMap{ $0.failure }
		guard errors.isEmpty else {
			throw ErrorCollection(errors)
		}
		return results.allSatisfy{ $0.successValue == true }
	}
	
	public func onContext_didImportRemoteResults(_ importChanges: LocalDbChanges<LocalDbObject, Metadata>) throws {
		let errors = [
			Result{ try requestHelper1?.onContext_didImportRemoteResults(importChanges) }.failure,
			Result{ try requestHelper1?.onContext_didImportRemoteResults(importChanges) }.failure,
			Result{ try requestHelper1?.onContext_didImportRemoteResults(importChanges) }.failure
		].compactMap{ $0 }
		guard errors.isEmpty else {
			throw ErrorCollection(errors)
		}
	}
	
	public func onContext_didFailImportingRemoteResults(_ error: Error) {
		requestHelper1?.onContext_didFailImportingRemoteResults(error)
		requestHelper2?.onContext_didFailImportingRemoteResults(error)
		requestHelper3?.onContext_didFailImportingRemoteResults(error)
	}
	
}
