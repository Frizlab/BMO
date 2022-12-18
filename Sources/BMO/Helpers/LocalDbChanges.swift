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



public struct LocalDbChanges<LocalDbObject : LocalDbObjectProtocol, Metadata> {
	
	public struct ImportedObject {
		
		public var object: LocalDbObject
		public var modifiedRelationships: [LocalDbObject.DbRelationshipDescription: LocalDbChanges?]
		
		public init(object: LocalDbObject, modifiedRelationships: [LocalDbObject.DbRelationshipDescription : LocalDbChanges?] = [:]) {
			self.object = object
			self.modifiedRelationships = modifiedRelationships
		}
		
	}
	
	public var metadata: Metadata?
	/**
	 First level of imported objects.
	 
	 If you import an object `A` which has a relationship to object `B`, only object `A` will be present in this array.
	 `B` will still be reachable through ``ImportedObject/modifiedRelationships``. */
	public var importedObjects = [ImportedObject]()
	
	/**
	 All the objects explicitly inserted by the importer for the given imported objects.
	 
	 If you import an object `A` which has a relationship to object `B` and `C`, with only `C` already present in the local db, this set will contain `A` and `B`.
	 In the sub-imported objects for the relationship which contains `B`, only `B` will be present in this set.
	 
	 Implicit insertion may not be present. */
	public var insertedDbObjects = Set<LocalDbObject>()
	/**
	 All the objects explicitly updated by the importer for the given imported objects.
	 
	 If you import an object `A` which has a relationship to object `B` and `C`, with `A` and `C` already present in the local db, this set will contain `A` and `C`.
	 In the sub-imported objects for the relationship which contains `C`, `C` will still be present in the set.
	 
	 Implicit updates may not be present. */
	public var updatedDbObjects = Set<LocalDbObject>()
	/**
	 All the objects explicitly deleted by the importer for the given imported objects.
	 
	 Implicit deletion may not be present. */
	public var deletedDbObjects = Set<LocalDbObject>()
	
	public init(metadata: Metadata?) {
		self.metadata = metadata
	}
	
}
