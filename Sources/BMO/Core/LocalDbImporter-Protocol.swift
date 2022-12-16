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
 Objects conforming to this protocol are responsible for importing ``GenericLocalDbObject``s into the local db, uniquing/deduplicating them. */
public protocol LocalDbImporterProtocol {
	
	associatedtype LocalDb : LocalDbProtocol
	associatedtype ImportResults
	
	/**
	 Import the given local representations into the given local db’s context.
	 
	 This method will **NOT** be called on the given db context.
	 `contextSwitchHandler` must be called before doing anything on the context though.
	 
	 The handler is used by the bridge operation to notify interested parties the import _will_ start. */
	func `import`<UniquingID : Hashable & Sendable, Metadata>(
		localRepresentations: [GenericLocalDbObject<LocalDb.DbObject, UniquingID, Metadata>], in db: LocalDb,
		contextSwitchHandler: @escaping @Sendable () throws -> Void
	) throws -> ImportResults
	
}
