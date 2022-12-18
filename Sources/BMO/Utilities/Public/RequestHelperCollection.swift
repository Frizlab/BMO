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



@available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
public struct RequestHelperCollection<LocalDbImporter : LocalDbImporterProtocol> : RequestHelperProtocol {
	
	public let requestHelpers: [any RequestHelperProtocol<LocalDbImporter>]
	
	public init(requestHelpers: [any RequestHelperProtocol<LocalDbImporter>]) {
		self.requestHelpers = requestHelpers
	}
	
	public func onContext_requestNeedsRemote() throws -> Bool {
		return try requestHelpers.contains(where: { try $0.onContext_requestNeedsRemote() })
	}
	
	public func onContext_failedRemoteConversion(_ error: Error) {
		requestHelpers.forEach{ $0.onContext_failedRemoteConversion(error) }
	}
	
	public func onContext_willGoRemote() throws {
		let errors = requestHelpers.compactMap{ requestHelper in
			do    {try requestHelper.onContext_willGoRemote()}
			catch {return error}
			return nil
		}
		if !errors.isEmpty {
			throw ErrorCollection(errors)
		}
	}
	
	public func importerForRemoteResults(localRepresentations: [GenericLocalDbObject<LocalDb.DbObject, LocalDb.UniquingID, LocalDbImporter.Metadata>], uniquingIDsPerEntities: [LocalDb.DbObject.DbEntityDescription : Set<LocalDb.UniquingID>]) -> LocalDbImporter? {
		/* We take the first non-nil local db importer, and we ignore the errors… */
		return requestHelpers.lazy.compactMap{ try? callHelperImporterForRemoteResults(requestHelper: $0, localRepresentations: localRepresentations, uniquingIDsPerEntities: uniquingIDsPerEntities) }.first{ _ in true }
	}
	
	public func onContext_willImportRemoteResults() throws -> Bool {
		let results = requestHelpers.map{ requestHelper in
			Result{ try requestHelper.onContext_willImportRemoteResults() }
		}
		let errors = results.compactMap{ $0.failure }
		if !errors.isEmpty {
			throw ErrorCollection(errors)
		}
		return results.allSatisfy{ $0.successValue == true }
	}
	
	public func onContext_didImportRemoteResults<Metadata>(_ importChanges: LocalDbChanges<LocalDb.DbObject, Metadata>) throws {
		let errors = requestHelpers.compactMap{ requestHelper in
			do    {try callHelperDidImportRemoteResults(requestHelper: requestHelper, importChanges: importChanges)}
			catch {return error}
			return nil
		}
		if !errors.isEmpty {
			throw ErrorCollection(errors)
		}
	}
	
	public func onContext_didFailImportingRemoteResults(_ error: Error) {
		requestHelpers.forEach{ $0.onContext_didFailImportingRemoteResults(error) }
	}
	
	/* Maybe in a future version of Swift this method will be able to be skipped. */
	private func callHelperImporterForRemoteResults<RequestHelper : RequestHelperProtocol>(requestHelper: RequestHelper, localRepresentations: [GenericLocalDbObject<LocalDb.DbObject, LocalDb.UniquingID, LocalDbImporter.Metadata>], uniquingIDsPerEntities: [LocalDb.DbObject.DbEntityDescription : Set<LocalDb.UniquingID>]) throws -> LocalDbImporter?
	where RequestHelper.LocalDbImporter == LocalDbImporter {
		return try requestHelper.importerForRemoteResults(localRepresentations: localRepresentations, uniquingIDsPerEntities: uniquingIDsPerEntities)
	}
	
	/* Maybe in a future version of Swift this method will be able to be skipped. */
	private func callHelperDidImportRemoteResults<RequestHelper : RequestHelperProtocol, Metadata>(requestHelper: RequestHelper, importChanges: LocalDbChanges<LocalDb.DbObject, Metadata>)
	throws where RequestHelper.LocalDbImporter == LocalDbImporter {
		try requestHelper.onContext_didImportRemoteResults(importChanges)
	}
	
}
