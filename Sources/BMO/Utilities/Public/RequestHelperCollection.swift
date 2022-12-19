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
public struct RequestHelperCollection<LocalDbObject : LocalDbObjectProtocol, Metadata> : RequestHelperProtocol {
	
	public let requestHelpers: [any RequestHelperProtocol<LocalDbObject, Metadata>]
	
	public init(requestHelpers: [any RequestHelperProtocol<LocalDbObject, Metadata>]) {
		self.requestHelpers = requestHelpers
	}
	
	public func onContext_requestNeedsRemote() throws -> Bool {
		guard !requestHelpers.isEmpty else {
			return true
		}
		return try requestHelpers.contains(where: { try $0.onContext_requestNeedsRemote() })
	}
	
	public func onContext_failedRemoteConversion(_ error: Error) {
		requestHelpers.forEach{ $0.onContext_failedRemoteConversion(error) }
	}
	
	public func onContext_willGoRemote() throws {
		let errors = requestHelpers.compactMap{ requestHelper in
			Result{ try requestHelper.onContext_willGoRemote() }.failure
		}
		guard errors.isEmpty else {
			throw ErrorCollection(errors)
		}
	}
	
	public func onContext_willImportRemoteResults() throws -> Bool {
		let results = requestHelpers.map{ requestHelper in
			Result{ try requestHelper.onContext_willImportRemoteResults() }
		}
		let errors = results.compactMap{ $0.failure }
		guard errors.isEmpty else {
			throw ErrorCollection(errors)
		}
		/* allSatisfy returns true if the collection is empty. */
		return results.allSatisfy{ $0.successValue == true }
	}
	
	public func onContext_didImportRemoteResults(_ importChanges: LocalDbChanges<LocalDbObject, Metadata>) throws {
		let errors = requestHelpers.compactMap{ requestHelper in
			Result{ try callHelperDidImportRemoteResults(requestHelper: requestHelper, importChanges: importChanges) }.failure
		}
		guard errors.isEmpty else {
			throw ErrorCollection(errors)
		}
	}
	
	public func onContext_didFailImportingRemoteResults(_ error: Error) {
		requestHelpers.forEach{ $0.onContext_didFailImportingRemoteResults(error) }
	}
	
	/* Maybe in a future version of Swift this method will be able to be skipped. */
	private func callHelperDidImportRemoteResults<RequestHelper : RequestHelperProtocol>(requestHelper: RequestHelper, importChanges: LocalDbChanges<LocalDbObject, Metadata>)
	throws where RequestHelper.LocalDbObject == LocalDbObject, RequestHelper.Metadata == Metadata {
		try requestHelper.onContext_didImportRemoteResults(importChanges)
	}
	
}
