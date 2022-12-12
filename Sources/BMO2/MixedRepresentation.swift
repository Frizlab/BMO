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



public struct MixedRepresentation<LocalDb : LocalDbProtocol, RemoteObjectsReader : RemoteObjectsReaderProtocol> {
	
	public typealias LocalDbEntityDescription = LocalDb.Object.EntityDescription
	public typealias RelationshipMergeType = BMO2.RelationshipMergeType<LocalDb.Object, LocalDb.Object.RelationshipDescription>
	
	/* Should be a struct. */
	public typealias RelationshipValue = (expectedEntity: LocalDbEntityDescription, mergeType: RelationshipMergeType, value: RemoteObjectsReader)?
	
	public var entity: LocalDbEntityDescription
	
	public var uniquingID: AnyHashable?
	public var attributes: [LocalDb.Object.AttributeDescription: Any?]
	public var relationships: [LocalDb.Object.RelationshipDescription: RelationshipValue]
	
	public init(
		entity: LocalDbEntityDescription,
		uniquingID: AnyHashable? = nil,
		attributes: [LocalDb.Object.AttributeDescription : Any?] = [:],
		relationships: [LocalDb.Object.RelationshipDescription : RelationshipValue] = [:]
	) {
		self.entity = entity
		self.uniquingID = uniquingID
		self.attributes = attributes
		self.relationships = relationships
	}
	
}
