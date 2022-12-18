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
 A protocol that simplify the complex process of converting a remote object to the local db.
 Objects conforming to this protocol are responsible for doing the business logic of the conversion from a remote object to an object in the local db.
 
 The main goal of a “BridgeObjects” is to be able to convert a collection of remote objects to its corresponding collection of ``MixedRepresentation``.
 
 A ``MixedRepresentation`` represents a single local db object.
 The representation is “mixed” because
  the attributes should be exactly what will be in the local db,
  the relationships’ _keys_ are also 1:1 with the local db,
  but the relationship’ _values_ will be ``BridgeObjectsProtocol``s (and the merge type of the relationship).
 
 This way we create a way to traverse the whole remote objects tree while keeping the work from the protocol adopters relatively light. */
public protocol BridgeObjectsProtocol {
	
	associatedtype LocalDb : LocalDbProtocol
	associatedtype RemoteDb : RemoteDbProtocol
	
	/**
	 The data returned by the remote operation that do not belong in the local db but that can be interested anyway.
	 
	 This can be the total number of items in a collection for instance. */
	associatedtype Metadata : Sendable
	
	var localMetadata: Metadata? {get}
	var remoteObjects: [RemoteDb.RemoteObject] {get}
	
	/* One of these two methods must be implemented.
	 * Specifically, mixedRepresentations() is called by BMO explicitly.
	 *
	 * mixedRepresentation(from:) is a convenience that can be implemented instead of mixedRepresentations().
	 * The default implementation of mixedRepresentations() will simply compactMap all the remote objects with their corresponding mixed representation.
	 *
	 * In general, implementing mixedRepresentation(from:) is ok and suffice.
	 * If for some reasons it does not, you can override mixedRepresentations() directly, in which case mixedRepresentation(from:) will be completely ignored by BMO. */
	
	func mixedRepresentations() throws -> [MixedRepresentation<Self>]
	func mixedRepresentation(from remoteObject: RemoteDb.RemoteObject) throws -> MixedRepresentation<Self>?
	
}


public extension BridgeObjectsProtocol {
	
	func mixedRepresentations() throws -> [MixedRepresentation<Self>] {
		return try remoteObjects.compactMap{ try mixedRepresentation(from: $0) }
	}
	
	func mixedRepresentation(from remoteObject: RemoteDb.RemoteObject) throws -> MixedRepresentation<Self>? {
		return nil
	}
	
}



/**
 A structure that simplify the complex process of converting a remote object to the local db.
 
 This works closely with the ``BridgeObjectsProtocol``.
 See its documentation for more info. */
public struct MixedRepresentation<BridgeObjects : BridgeObjectsProtocol> {
	
	public typealias DbObject = BridgeObjects.LocalDb.DbObject
	public typealias MergeType = BMO.RelationshipMergeType<DbObject, DbObject.DbRelationshipDescription>
	
	public var entity: DbObject.DbEntityDescription
	
	public var uniquingID: BridgeObjects.LocalDb.UniquingID?
	public var attributes: [DbObject.DbAttributeDescription: Any?]
	public var relationships: [DbObject.DbRelationshipDescription: (objects: BridgeObjects, mergeType: MergeType)?]
	
	public init(
		entity: DbObject.DbEntityDescription,
		uniquingID: BridgeObjects.LocalDb.UniquingID? = nil,
		attributes: [DbObject.DbAttributeDescription : Any?] = [:],
		relationships: [DbObject.DbRelationshipDescription: (BridgeObjects, MergeType)?] = [:]
	) {
		self.entity = entity
		self.uniquingID = uniquingID
		self.attributes = attributes
		self.relationships = relationships
	}
	
}
