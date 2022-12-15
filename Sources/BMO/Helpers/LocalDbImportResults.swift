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



public struct LocalDbImportResult<LocalDbObject : LocalDbObjectProtocol> {
	
	/* NO bridge metadata here.
	 * This stricly represents the results of the LocalDbImporter. */
	
	public struct ImportedObject {
		
		public var object: LocalDbObject
		public var modifiedRelationships: [LocalDbObject.DbRelationshipDescription: LocalDbImportResult]
		
		internal init(object: LocalDbObject, modifiedRelationships: [LocalDbObject.DbRelationshipDescription : LocalDbImportResult]) {
			self.object = object
			self.modifiedRelationships = modifiedRelationships
		}
		
	}
	
	public var importedObjects: [ImportedObject]
	
	internal init(importedObjects: [ImportedObject]) {
		self.importedObjects = importedObjects
	}
	
}
