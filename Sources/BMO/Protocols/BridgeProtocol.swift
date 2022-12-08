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
	
	/* *************
	   MARK: - Types
	   ************* */
	
	associatedtype Db : DbProtocol
	associatedtype AdditionalRequestInfo
	
	associatedtype BackOperation : Operation
	
	/**
	 A type to store "relationship" or "root" metadata.
	 Whenever you need to store information for the caller that is not part of the model (eg. next or previous page info), you can use the metadata.
	 
	 There are no object or attributes metadata; you'll have to store those (if any) directly in your model, possibly in transient properties. */
	associatedtype Metadata
	
	/**
	 Will typically be `[String: Any]`, or some kind of `JSON` enum (e.g. GenericJSON) if you don’t have the model of your API.
	 If you do, you’ll probably want to make all of the types returned by your API to a common protocol and use this protocol here. */
	associatedtype RemoteObjectRepresentation
	/** Usually the same type as `RemoteObjectRepresentation`. */
	associatedtype RemoteRelationshipRepresentation
	
	/**
	 An internal type you can use for basically whatever you want.
	 For instance if you need information about the original request when converting from remote object representation to mixed representation, you can use this type. */
	associatedtype UserInfo
	
	func createUserInfoObject() -> UserInfo
	
	/* ***********************
	   MARK: - Methods
	   MARK: → Local to Remote
	   *********************** */
	
	func expectedResultEntity(for fetchRequest: Db.FetchRequest, additionalInfo: AdditionalRequestInfo?) -> Db.EntityDescription
	func expectedResultEntity(for object: Db.Object) -> Db.EntityDescription
	
	func backOperation(forFetch fetchRequest: Db.FetchRequest, additionalInfo: AdditionalRequestInfo?, userInfo: inout UserInfo) throws -> BackOperation?
	
	func backOperation(forInserted object: Db.Object, additionalInfo: AdditionalRequestInfo?, userInfo: inout UserInfo) throws -> BackOperation?
	func backOperation(forUpdated  object: Db.Object, additionalInfo: AdditionalRequestInfo?, userInfo: inout UserInfo) throws -> BackOperation?
	func backOperation(forDeleted  object: Db.Object, additionalInfo: AdditionalRequestInfo?, userInfo: inout UserInfo) throws -> BackOperation?
	
	/* ***********************
	   MARK: → Remote to Local
	   *********************** */
	/* NOT called on a db context. If you need to be on a db context you're probably doing it wrong… */
	
	/**
	 Called when the back operation is finished, for requests who do not want the operation results to be imported in the db.
	 Return `nil` if the operation was successful. */
	func error(from finishedOperation: BackOperation) -> Error?
	
	func userInfo(from finishedOperation: BackOperation, currentUserInfo: UserInfo) -> UserInfo
	
	/**
	 Return here info that can be of use for the client but do not need to be saved in the model.
	 
	 Eg. The paginator info for getting the next page do not always have to be saved in the model as usually when the app relaunches we load the pages from the first one.
	 To simplify the model, you can use metadata to return the paginator info for the next page without saving them in the model. */
	func bridgeMetadata(from finishedOperation: BackOperation, userInfo: UserInfo) throws -> Metadata?
	
	/**
	 This method should extract the remote representation of the retrieved objects from the finished back operation.
	 For each remote representation returned, the bridge will be called to extract the attributes and relationships for the object.
	 
	 Returning an empty array to skip the import is possible. */
	func remoteObjectRepresentations(from finishedOperation: BackOperation, userInfo: UserInfo) throws -> [RemoteObjectRepresentation]
	
	typealias MixedRepresentation = BMO.MixedRepresentation<Db.EntityDescription, RemoteRelationshipRepresentation, UserInfo>
	func mixedRepresentation(from remoteObjectRepresentation: RemoteObjectRepresentation, expectedEntity: Db.EntityDescription, userInfo: UserInfo) throws -> MixedRepresentation?
	
	func subUserInfo(from remoteRelationshipRepresentation: RemoteRelationshipRepresentation, relationshipName: String, parentMixedRepresentation: MixedRepresentation) -> UserInfo
	func relationshipMergeType(for relationshipName: String, in parentMixedRepresentation: MixedRepresentation) -> DbRepresentationRelationshipMergeType<Db.Object>
	
	func metadata(from remoteRelationshipRepresentation: RemoteRelationshipRepresentation, userInfo: UserInfo) throws -> Metadata?
	func remoteObjectRepresentations(from remoteRelationshipRepresentation: RemoteRelationshipRepresentation, userInfo: UserInfo) throws -> [RemoteObjectRepresentation]?
	
}


public enum DbRepresentationRelationshipMergeType<DbObject> {
	
	case replace
	case append
	case insertAtBeginning
	case custom(mergeHandler: (_ object: DbObject, _ relationshipName: String, _ newValues: [DbObject]) -> Void)
	
	public var isReplace: Bool {
		switch self {
			case .replace: return true
			default:       return false
		}
	}
	
}
