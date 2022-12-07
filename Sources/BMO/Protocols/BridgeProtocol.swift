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



public protocol BridgeProtocol {
	
	associatedtype Db : DbProtocol
	associatedtype AdditionalRequestInfo
	
	/**
	 An internal type you can use for basically whatever you want.
	 For instance if you need information about the original request when converting from remote object representation to mixed representation, you can use this type. */
	associatedtype UserInfo
	
	/**
	 A type to store "relationship" or "root" metadata.
	 Whenever you need to store information for the caller that is not part of the model (eg. next or previous page info), you can use the metadata.
	 
	 There are no object or attributes metadata; you'll have to store those (if any) directly in your model, possibly in transient properties. */
	associatedtype Metadata
	
	/** Typically `[String: Any]` (the type of a JSON object). */
	associatedtype RemoteObjectRepresentation
	/**
	 Some APIs (eg. Facebook’s) give both a data and a metadata field in their relationship values.
	 For other APIs, this type will probably simply be an array of `RemoteObjectRepresentation`. */
	associatedtype RemoteRelationshipAndMetadataRepresentation
	
	associatedtype BackOperation : Operation
	
	func createUserInfoObject() -> UserInfo
	
	/* Bridging -- Front end => Back end. Called on the correct db context. */
	
	func expectedResultEntity(forFetchRequest fetchRequest: Db.FetchRequest, additionalInfo: AdditionalRequestInfo?) -> Db.EntityDescription?
	func expectedResultEntity(forObject object: Db.Object) -> Db.EntityDescription?
	
	func backOperation(forFetchRequest fetchRequest: Db.FetchRequest, additionalInfo: AdditionalRequestInfo?, userInfo: inout UserInfo) throws -> BackOperation?
	
	func backOperation(forInsertedObject insertedObject: Db.Object, additionalInfo: AdditionalRequestInfo?, userInfo: inout UserInfo) throws -> BackOperation?
	func backOperation(forUpdatedObject updatedObject: Db.Object, additionalInfo: AdditionalRequestInfo?, userInfo: inout UserInfo) throws -> BackOperation?
	func backOperation(forDeletedObject deletedObject: Db.Object, additionalInfo: AdditionalRequestInfo?, userInfo: inout UserInfo) throws -> BackOperation?
	
	/* Bridging -- Back end => Front end. NOT called on a db context. If you need to be on a db context you're probably doing it wrong… */
	
	/**
	 Called when the back operation is finished, for requests who do not want the operation results to be imported in the db.
	 Return `nil` if the operation was successful. */
	func error(fromFinishedOperation operation: BackOperation) -> Error?
	
	func userInfo(fromFinishedOperation operation: BackOperation, currentUserInfo: UserInfo) -> UserInfo
	
	/**
	 Return here info that can be of use for the client but do not need to be saved in the model.
	 
	 Eg. The paginator info for getting the next page do not always have to be saved in the model as usually when the app relaunches we load the pages from the first one.
	 To simplify the model, you can use metadata to return the paginator info for the next page without saving them in the model. */
	func bridgeMetadata(fromFinishedOperation operation: BackOperation, userInfo: UserInfo) -> Metadata?
	
	/**
	 This method should extract the remote representation of the retrieved objects from the finished back operation.
	 For each remote representation returned, the bridge will be called to extract the attributes and relationships for the object.
	 
	 Return `nil` if the results should not be imported at all. */
	func remoteObjectRepresentations(fromFinishedOperation operation: BackOperation, userInfo: UserInfo) throws -> [RemoteObjectRepresentation]?
	
	func mixedRepresentation(fromRemoteObjectRepresentation remoteRepresentation: RemoteObjectRepresentation, expectedEntity: Db.EntityDescription, userInfo: UserInfo) -> MixedRepresentation<Db.EntityDescription, RemoteRelationshipAndMetadataRepresentation, UserInfo>?
	
	func subUserInfo(forRelationshipNamed relationshipName: String, inEntity entity: Db.EntityDescription, currentMixedRepresentation: MixedRepresentation<Db.EntityDescription, RemoteRelationshipAndMetadataRepresentation, UserInfo>) -> UserInfo
	func metadata(fromRemoteRelationshipAndMetadataRepresentation remoteRelationshipAndMetadataRepresentation: RemoteRelationshipAndMetadataRepresentation, userInfo: UserInfo) -> Metadata?
	func remoteObjectRepresentations(fromRemoteRelationshipAndMetadataRepresentation remoteRelationshipAndMetadataRepresentation: RemoteRelationshipAndMetadataRepresentation, userInfo: UserInfo) -> [RemoteObjectRepresentation]?
	
	func relationshipMergeType(forRelationshipNamed relationshipName: String, inEntity entity: Db.EntityDescription, currentMixedRepresentation: MixedRepresentation<Db.EntityDescription, RemoteRelationshipAndMetadataRepresentation, UserInfo>) -> DbRepresentationRelationshipMergeType<Db.EntityDescription, Db.Object>
	
}


public enum DbRepresentationRelationshipMergeType<DbEntityDescription, DbObject> {
	
	case replace
	case append
	case insertAtBeginning
	case custom(mergeHandler: (_ object: DbObject, _ relationshipName: String, _ values: [DbObject]) -> Void)
	
	public var isReplace: Bool {
		switch self {
			case .replace: return true
			default:       return false
		}
	}
	
}
