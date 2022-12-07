/*
Copyright 2019 happn

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



/* Note: This protocol is not used directly in BMO yet (but new requests type will be created that will need it). */
public protocol DbRepresentationImporter {
	
	associatedtype Db : DbProtocol
	associatedtype ResultType
	
	func prepareImport() throws
	
	/** Always called on the db context. */
	func unsafeImport(in db: Db, updatingObject updatedObject: Db.Object?) throws -> ResultType
	
}


/* *********************************************
   MARK: - Single Thread Importer Result Builder
   ********************************************* */

/* RFC */
public protocol SingleThreadDbRepresentationImporterResultBuilder {
	
	associatedtype Db : DbProtocol
	associatedtype DbRepresentationUserInfo
	
	associatedtype ResultType
	
	func unsafeStartedImporting(object: Db.Object, inDb db: Db) throws
	func unsafeStartImporting(relationshipName: String, userInfo: DbRepresentationUserInfo?) throws -> Self
	func unsafeFinishedImportingCurrentObject(inDb db: Db) throws
	
	func unsafeInserted(object: Db.Object, fromDb db: Db) throws
	func unsafeUpdated(object: Db.Object, fromDb db: Db) throws
	func unsafeDeleted(object: Db.Object, fromDb db: Db) throws
	
	func unsafeFinishedImport(inDb db: Db) throws
	
	/* Shall not be accessed before unsafeFinishedImport is called. */
	var result: ResultType {get}
	
}
