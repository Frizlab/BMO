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
 A generic representation of an object to import in the local db.
 
 This is the direct counterpart of a ``MixedRepresentation``, except the relationships are fully resolved in this structure.
 
 You should rarely have to build a ``GenericLocalDbObject`` manually.
 Instead, BMO will construct a collection of ``GenericLocalDbObject`` from a ``BridgeObjectsProtocol`` and pass them to a ``LocalDbImporterProtocol`` instance. */
public struct GenericLocalDbObject<DbObject : LocalDbObjectProtocol, UniquingID : Hashable & Sendable, RelationshipMetadata> {
	
	public typealias RelationshipMergeType = BMO.RelationshipMergeType<DbObject, DbObject.DbRelationshipDescription>
	public typealias RelationshipValue = (value: [Self], mergeType: RelationshipMergeType, metadata: RelationshipMetadata?)
	
	public var entity: DbObject.DbEntityDescription
	
	public var uniquingID: UniquingID?
	public var attributes: [DbObject.DbAttributeDescription: Any?]
	public var relationships: [DbObject.DbRelationshipDescription: RelationshipValue?]
	
	public var hasAttributesOrRelationships: Bool {
		return !attributes.isEmpty || !relationships.isEmpty
	}
	
	/**
	 Convert the given bridge objects to an array of local db representations.
	 
	 This method will traverse the whole object tree represented by the bridge objects and convert each objects to a local db representation.
	 
	 This conversion can take some time.
	 That’s why it can be stopped at any point using the `taskCancelled` handler.
	 If you call this method in a structured concurrency context, the handler can simply return `Task.isCancelled` for instance. */
	public static func objects<BridgeObjects : BridgeObjectsProtocol>(from bridgeObjects: BridgeObjects, uniquingIDsPerEntities: inout [DbObject.DbEntityDescription: Set<UniquingID>], cancellationCheck throwIfCancelled: () throws -> Void = { }) throws -> [Self]
	where BridgeObjects.LocalDb.DbObject == DbObject, BridgeObjects.LocalDb.UniquingID == UniquingID, BridgeObjects.Metadata == RelationshipMetadata {
		return try bridgeObjects.mixedRepresentations().map{ mixedRepresentation in
			try throwIfCancelled()
			
			if let uniquingID = mixedRepresentation.uniquingID {
				uniquingIDsPerEntities[mixedRepresentation.entity, default: []].insert(uniquingID)
			}
			
			return self.init(
				entity: mixedRepresentation.entity,
				uniquingID: mixedRepresentation.uniquingID,
				attributes: mixedRepresentation.attributes,
				relationships: try mixedRepresentation.relationships.mapValues{ relationshipBridgeObjectsAndMergeType in
					guard let (relationshipBridgeObjects, mergeType) = relationshipBridgeObjectsAndMergeType else {
						return nil
					}
					let relationshipLocalRepresentation = try Self.objects(from: relationshipBridgeObjects, uniquingIDsPerEntities: &uniquingIDsPerEntities, cancellationCheck: throwIfCancelled)
					return (value: relationshipLocalRepresentation, mergeType: mergeType, metadata: relationshipBridgeObjects.localMetadata)
				}
			)
		}
	}
	
	public init(
		entity: DbObject.DbEntityDescription,
		uniquingID: UniquingID? = nil,
		attributes: [DbObject.DbAttributeDescription : Any?] = [:],
		relationships: [DbObject.DbRelationshipDescription : RelationshipValue?] = [:]
	) {
		self.entity = entity
		self.uniquingID = uniquingID
		self.attributes = attributes
		self.relationships = relationships
	}
	
	public func insertUniquingIDsPerEntities(in uniquingIDsPerEntities: inout [DbObject.DbEntityDescription: Set<UniquingID>], cancellationCheck throwIfCancelled: () throws -> Void) rethrows {
		try relationships.forEach{
			try throwIfCancelled()
			try $0.value?.value.forEach{
				try throwIfCancelled()
				try $0.insertUniquingIDsPerEntities(in: &uniquingIDsPerEntities, cancellationCheck: throwIfCancelled)
			}
		}
		if let uniquingID {
			uniquingIDsPerEntities[entity, default: []].insert(uniquingID)
		}
	}
	
}
