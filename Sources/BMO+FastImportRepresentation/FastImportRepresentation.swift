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

import BMO



public struct FastImportRepresentation<DbEntityDescription, DbObject, RelationshipUserInfo> {
	
	public typealias RelationshipValue = (
		value: ([FastImportRepresentation<DbEntityDescription, DbObject, RelationshipUserInfo>], DbRepresentationRelationshipMergeType<DbObject>)?,
		userInfo: RelationshipUserInfo?
	)
	
	public let entity: DbEntityDescription
	
	public let uniquingId: AnyHashable?
	public let attributes: [String: Any?]
	public let relationships: [String: RelationshipValue]
	
	/**
	 Creates an array of fast import representations from remote representations using the given bridge.
	 A handler can be given to stop the conversion at any given time.
	 
	 - Important: If the `shouldContinueHandler` returns `false` at any given time during the conversion,
	  the fast import representations returned will probably be incomplete and should be ignored.
	 
	 - Note: I’d like the `shouldContinueHandler` to be optional, but cannot be non-escaping if optional with current Swift status :( */
	public static func fastImportRepresentations<Bridge : BridgeProtocol>(fromRemoteRepresentations remoteRepresentations: [Bridge.RemoteObjectRepresentation], expectedEntity entity: Bridge.Db.EntityDescription, userInfo: Bridge.UserInfo, bridge: Bridge, shouldContinueHandler: () -> Bool = {true}) throws -> [FastImportRepresentation<DbEntityDescription, DbObject, RelationshipUserInfo>]
	where DbEntityDescription == Bridge.Db.EntityDescription, DbObject == Bridge.Db.Object, RelationshipUserInfo == Bridge.Metadata
	{
		var fastImportRepresentations = [FastImportRepresentation<DbEntityDescription, DbObject, RelationshipUserInfo>]()
		for remoteRepresentation in remoteRepresentations {
			guard shouldContinueHandler() else {break}
			if let fastImportRepresentation = try FastImportRepresentation(remoteRepresentation: remoteRepresentation, expectedEntity: entity, userInfo: userInfo, bridge: bridge, shouldContinueHandler: shouldContinueHandler) {
				fastImportRepresentations.append(fastImportRepresentation)
			}
		}
		return fastImportRepresentations
	}
	
	/**
	 Creates a fast import representation from a remote representation.
	 
	 As this process can be long, it can be cancelled using the `shouldContinueHandler` block.
	 If the block returns `false` at any given time during the init process, `nil` will probably be returned.
	 If the init succeeds however, the returned fast-import representation is guaranteed to be the complete translation of the remote representation.
	 (The init will never return a half-completed translation.) */
	init?<Bridge : BridgeProtocol>(remoteRepresentation: Bridge.RemoteObjectRepresentation, expectedEntity: DbEntityDescription, userInfo info: Bridge.UserInfo, bridge: Bridge, shouldContinueHandler: () -> Bool = {true})
	throws
	where DbEntityDescription == Bridge.Db.EntityDescription, DbObject == Bridge.Db.Object, RelationshipUserInfo == Bridge.Metadata
	{
		guard let mixedRepresentation = try bridge.mixedRepresentation(from: remoteRepresentation, expectedEntity: expectedEntity, userInfo: info) else {
			return nil
		}
		
		var relationshipsBuilding = [String: RelationshipValue]()
		for (relationshipName, relationshipValue) in mixedRepresentation.relationships {
			guard shouldContinueHandler() else {return nil}
			guard let relationshipValue = relationshipValue else {
				relationshipsBuilding[relationshipName] = (value: nil, userInfo: nil)
				continue
			}
			
			let (relationshipEntity, relationshipRemoteRepresentations) = relationshipValue
			let subUserInfo = bridge.subUserInfo(from: relationshipRemoteRepresentations, relationshipName: relationshipName, parentMixedRepresentation: mixedRepresentation)
			let metadata = try bridge.metadata(from: relationshipRemoteRepresentations, userInfo: subUserInfo)
			
			guard let relationshipRemoteRepresentations = try bridge.remoteObjectRepresentations(from: relationshipRemoteRepresentations, userInfo: subUserInfo) else {
				relationshipsBuilding[relationshipName] = (value: nil, userInfo: metadata)
				continue
			}
			
			relationshipsBuilding[relationshipName] = (
				value: (
					try FastImportRepresentation<DbEntityDescription, DbObject, RelationshipUserInfo>.fastImportRepresentations(fromRemoteRepresentations: relationshipRemoteRepresentations, expectedEntity: relationshipEntity, userInfo: subUserInfo, bridge: bridge, shouldContinueHandler: shouldContinueHandler),
					bridge.relationshipMergeType(for: relationshipName, in: mixedRepresentation)
				),
				userInfo: metadata
			)
		}
		
		guard shouldContinueHandler() else {return nil}
		
		entity = mixedRepresentation.entity
		uniquingId = mixedRepresentation.uniquingId
		attributes = mixedRepresentation.attributes
		relationships = relationshipsBuilding
	}
	
}
