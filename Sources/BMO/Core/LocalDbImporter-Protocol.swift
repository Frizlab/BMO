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
public protocol LocalDbImporterProtocol<LocalDb, Metadata> {
	
	associatedtype LocalDb : LocalDbProtocol
	associatedtype Metadata
	
	/**
	 Import the known local db representations into the given local db’s context.
	 
	 Should import the given local db representation currently in your possession into the given local db.
	 Usually the db context should _not_ be saved after the import; this should be the job of the request helper.
	 
	 During the import task, one should call `throwIfCancelled` from time to time.
	 This block will throw if the calling operation is cancelled.
	 Import should stop when this block throws. */
	func onContext_import(in db: LocalDb, cancellationCheck throwIfCancelled: () throws -> Void) throws -> LocalDbChanges<LocalDb.DbObject, Metadata>
	
}
