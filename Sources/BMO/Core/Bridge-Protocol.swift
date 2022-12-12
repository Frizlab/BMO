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



public protocol BridgeProtocol {
	
	associatedtype LocalDb : LocalDbProtocol
	associatedtype RemoteDb : RemoteDbProtocol
	
	/**
	 The type for the additional user info needed to help convert a local db request to a remote operation. */
	associatedtype RequestUserInfo
	
	/**
	 The data returned by the remote operation that do not belong in the local db but that can be interested anyway.
	 
	 This can be the total number of items in a collection for instance. */
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
	associatedtype BridgeObjects : BridgeObjectsProtocol where BridgeObjects.Metadata == Metadata
	
	/* These two methods could probably be replaced by one async method.
	 * This would also allow getting rid of the UserInfo associated type. */
	func remoteOperation(for bmoRequest: BMORequest<LocalDb.Request, RequestUserInfo>) throws -> (RemoteDb.RemoteOperation, UserInfo)?
	func bridgeObjects(for finishedRemoteOperation: RemoteDb.RemoteOperation, userInfo: UserInfo) throws -> BridgeObjects?
	
}
