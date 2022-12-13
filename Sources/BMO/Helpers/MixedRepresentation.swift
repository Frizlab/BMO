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



public struct MixedRepresentation<BridgeObjects : BridgeObjectsProtocol> {
	
	public typealias DbObject = BridgeObjects.LocalDb.DbObject
	
	public var entity: DbObject.DbEntityDescription
	
	public var uniquingID: BridgeObjects.LocalDb.UniquingID?
	public var attributes: [DbObject.DbAttributeDescription: Any?]
	public var relationships: [DbObject.DbRelationshipDescription: BridgeObjects?]
	
	public init(
		entity: DbObject.DbEntityDescription,
		uniquingID: BridgeObjects.LocalDb.UniquingID? = nil,
		attributes: [DbObject.DbAttributeDescription : Any?] = [:],
		relationships: [DbObject.DbRelationshipDescription : BridgeObjects?] = [:]
	) {
		self.entity = entity
		self.uniquingID = uniquingID
		self.attributes = attributes
		self.relationships = relationships
	}
	
}
