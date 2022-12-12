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



public protocol RemoteObjectsReaderProtocol<LocalDb, Metadata> {
	
	associatedtype LocalDb : LocalDbProtocol
	associatedtype RemoteDb : RemoteDbProtocol
	
	associatedtype Metadata
	
	associatedtype UserInfo
	
	init(remoteOperation: RemoteDb.RemoteOperation, userInfo: UserInfo)
	
	/* Conveniences init, disabled for now as not truly required. */
//	init(relationship: LocalDb.Object.RelationshipDescription, of remoteObject: RemoteDb.RemoteObject, userInfo: UserInfo)
	/* With this init, the metadata will probably alwasy be nil (no access to the parent object which presumably contains the Metadata). */
//	init(remoteObjects: [RemoteDb.RemoteObject], userInfo: UserInfo)
	
	func readMetadata() throws -> Metadata?
	func readMixedRepresentations() throws -> [MixedRepresentation<LocalDb, Self>]
	
}


public protocol BridgeProtocol {
	
	associatedtype LocalDb : LocalDbProtocol
	associatedtype RemoteDb : RemoteDbProtocol
	
	associatedtype AdditionalRequestsInfo
	
	/** The data returned by the remote operation that do not belong in the local db. */
	associatedtype Metadata
	
	/**
	 Some arbitrary type the bridge uses to ease or make possible the conversion between remote and local data.
	 
	 Remote data can be tricky; sometimes a “state” must be maintained in order for the conversion to be even possible.
	 
	 A simple example:
	 When requesting only certain fields from an object from a remote API, the local db representation should only contain the requested fields.
	 Whose fields were requested usually cannot be known with certainty without some additional info.
	 
	 This is an example, but there are loads of cases that cannot be solved without user info. */
	associatedtype UserInfo
	
	/**
	 The type of the object that will be responsible for doing the actual conversion from the remote objects to local db representations (``MixedRepresentation`` to be precise). */
	associatedtype RemoteObjectsReader : RemoteObjectsReaderProtocol where RemoteObjectsReader.UserInfo == UserInfo, RemoteObjectsReader.Metadata == Metadata
	
	func remoteOperation(forLocalFetch fetchRequest: LocalDb.FetchRequest, additionalRequestInfo: AdditionalRequestsInfo?) throws -> (RemoteDb.RemoteOperation, UserInfo)?
	
	func remoteOperation(forLocallyInserted object: LocalDb.Object, additionalRequestInfo: AdditionalRequestsInfo?) throws -> (RemoteDb.RemoteOperation, UserInfo)?
	func remoteOperation(forLocallyUpdated  object: LocalDb.Object, additionalRequestInfo: AdditionalRequestsInfo?) throws -> (RemoteDb.RemoteOperation, UserInfo)?
	func remoteOperation(forLocallyDeleted  object: LocalDb.Object, additionalRequestInfo: AdditionalRequestsInfo?) throws -> (RemoteDb.RemoteOperation, UserInfo)?
	
}
