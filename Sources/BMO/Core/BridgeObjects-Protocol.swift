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



public protocol BridgeObjectsProtocol<LocalDb, Metadata> {
	
	associatedtype LocalDb : LocalDbProtocol
	associatedtype RemoteDb : RemoteDbProtocol
	
	associatedtype Metadata
	
	var remoteObjects: [RemoteDb.RemoteObject] {get}
	
	var localMetadata: Metadata? {get}
	var localEntity: LocalDb.DbObject.DbEntityDescription {get}
	var localMergeType: RelationshipMergeType<LocalDb.DbObject, LocalDb.DbObject.DbRelationshipDescription> {get}
	
	/* If the object should not be imported at all, return nil. */
	func mixedRepresentation(from remoteObject: RemoteDb.RemoteObject) throws -> MixedRepresentation<Self>?
	
}


public extension BridgeObjectsProtocol {
	
	func mixedRepresentations() throws -> [MixedRepresentation<Self>] {
		return try remoteObjects.compactMap{ try mixedRepresentation(from: $0) }
	}
	
}


// TODO: Local Db Representation. Probably not here though.
//public extension BridgeObjectsProtocol {
//	
//	/**
//	 This will use the mixedRepresentation to create a local db representation.
//	 
//	 If isCancelled returns false at any point while this method has not returned, the result of this function should be considered garbage.
//	 
//	 Can probably be converted to async.
//	 We’d use Task.isCancelled instead of an `isCancelled` block. */
//	func convertToLocalDbRepresentations(isCancelled: () -> Bool = { false }) throws -> [LocalDbRepresentation<LocalDb.DbObject, Metadata>] {
//		var res = [LocalDbRepresentation<LocalDb.DbObject, Metadata>]()
//		return try remoteObjects.map{ object in
//			let uniquingID = try uniquingID(from: object)
//			let attributes = try attributes(from: object)
//			let relationships = try relationships(from: object)
//			return MixedRepresentation(
//				entity: localEntity,
//				uniquingID: uniquingID,
//				attributes: attributes,
//				relationships: relationships
//			)
//		}
//	}
//	
//}
