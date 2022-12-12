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
	
	associatedtype UserInfo
	
	init(remoteOperation: RemoteDb.RemoteOperation, expectedLocalEntity: LocalDb.Object.EntityDescription, userInfo: UserInfo)
	
	/* Conveniences init, disabled for now as not truly required. */
//	init(relationship: LocalDb.Object.RelationshipDescription, of remoteObject: RemoteDb.RemoteObject, userInfo: UserInfo)
	/* With this init, the metadata will probably alwasy be nil (no access to the parent object which presumably contains the Metadata). */
//	init(remoteObjects: [RemoteDb.RemoteObject], expectedLocalEntity: LocalDb.Object.EntityDescription, userInfo: UserInfo)
	
	var expectedLocalEntity: LocalDb.Object.EntityDescription {get}
	
	func readLocalMetadata() throws -> Metadata?
	func readRemoteObjects() throws -> [RemoteDb.RemoteObject]
	
	func readMergeType() throws -> RelationshipMergeType<LocalDb.Object, LocalDb.Object.RelationshipDescription>
	
	/* We put these three methods as required methods of the protocol instead of the one there is in the extension, for convenience.
	 * Whether it is more convenient is debatable.
	 * If debate thinks no, simple replace these three functions by the one in the extension (and remove its implementation). */
	func uniquingID(from remoteObject: RemoteDb.RemoteObject) throws -> AnyHashable?
	func attributes(from remoteObject: RemoteDb.RemoteObject) throws -> [LocalDb.Object.AttributeDescription: Any?]
	func relationships(from remoteObject: RemoteDb.RemoteObject) throws -> [LocalDb.Object.RelationshipDescription: Self?]
	
}


public extension BridgeObjectsProtocol {
	
	func readMixedRepresentations() throws -> [MixedRepresentation<LocalDb, Self>] {
		return try readRemoteObjects().map{ object in
			let uniquingID = try uniquingID(from: object)
			let attributes = try attributes(from: object)
			let relationships = try relationships(from: object)
			return MixedRepresentation(
				entity: expectedLocalEntity,
				uniquingID: uniquingID,
				attributes: attributes,
				relationships: relationships
			)
		}
	}
	
}
