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
	
	func readMetadata() throws -> Metadata?
	func readObjects() throws -> [RemoteDb.RemoteObject]
	
	func readMergeType() throws -> RelationshipMergeType<LocalDb.Object, LocalDb.Object.RelationshipDescription>
	
	/* These four methods should only be used by the readMixedRepresentations method in the extension of this protocol in this file.
	 * We deemed it more convenient for an implementer to implement these four functions rather than having to implement the mixed representations one directly.
	 * This is debatable and can easily be changed if needed. */
	var expectedLocalEntity: LocalDb.Object.EntityDescription {get}
	func uniquingID(from remoteObject: RemoteDb.RemoteObject) throws -> AnyHashable?
	func attributes(from remoteObject: RemoteDb.RemoteObject) throws -> [LocalDb.Object.AttributeDescription: Any?]
	func relationships(from remoteObject: RemoteDb.RemoteObject) throws -> [LocalDb.Object.RelationshipDescription: Self?]
	
}


public extension BridgeObjectsProtocol {
	
	func readMixedRepresentations() throws -> [MixedRepresentation<LocalDb, Self>] {
		return try readObjects().map{ object in
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
