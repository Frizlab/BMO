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
	
	/**
	 The type of the object that will be responsible for doing the actual conversion from the remote objects to local db representations (``MixedRepresentation`` to be precise). */
	associatedtype BridgeObjects : BridgeObjectsProtocol
	
	/**
	 The type for the additional user info needed to help convert a local db request to a remote operation. */
	associatedtype RequestUserInfo
	
	/**
	 Some arbitrary type the bridge uses to ease or make possible the conversion between the finished operation and the bridge objects.
	 
	 Usually a remote operation on its own will not contain any info for the local db.
	 Sometimes a “state” must be maintained in order for the conversion to bridge objects to be possible.
	 
	 A simple example:
	 When requesting only certain fields from an object from a remote API, the generic local db objects should only contain the requested fields.
	 Whose fields were requested usually cannot be known with certainty without some additional info.
	 
	 This is an example, but there are loads of cases that cannot be solved without user info. */
	associatedtype UserInfo : Sendable
	
	associatedtype LocalDbImporter : LocalDbImporterProtocol where LocalDbImporter.LocalDb == LocalDb, LocalDbImporter.Metadata == Metadata
	
	/* Convenience typealiases. */
	typealias LocalDb = BridgeObjects.LocalDb
	typealias RemoteDb = BridgeObjects.RemoteDb
	typealias Metadata = BridgeObjects.Metadata
	typealias RequestResults = BMO.RequestResult<RemoteDb.RemoteOperation, LocalDb.DbObject, Metadata>
	
	/**
	 Returns a request helper for the given request.
	 
	 The lifecycle of a request in BMO is something relatively complex.
	 First the remote operation is retrieved,
	  then the results of the operation are transformed into generic local db objects,
	  then the local db objects are imported.
	 
	 The general principle is not that complex, but in real life a lot of control is required at every point of the lifecycle of the request.
	 
	 This is the point of a request helper.
	 
	 The bridge is responsible for returning a request helper for a given request.
	 This function may not return `nil` because we think a request without a helper would not really be viable.
	 
	 If you _really_ do not need a helper, you can return a ``DummyRequestHelper`` which does nothing and returns `true` for all the methods returning a `Bool`. */
	func requestHelper(for request: Request<LocalDb, RequestUserInfo>) -> any RequestHelperProtocol<LocalDb.DbContext, LocalDb.DbObject, Metadata>
	
	/* These two methods could probably be replaced by one async method.
	 * This would also allow getting rid of the UserInfo associated type. */
	func onContext_remoteOperation(for request: Request<LocalDb, RequestUserInfo>) throws -> (RemoteDb.RemoteOperation, UserInfo)?
	func bridgeObjects(for finishedRemoteOperation: RemoteDb.RemoteOperation, userInfo: UserInfo) throws -> BridgeObjects?
	
	/**
	 Generates an importer specifically made to import the given local representations.
	 
	 You’re given the local representations that will be imported and the uniquing IDs found in the local representations by entities.
	 The uniquing IDs are given for possible optimization.
	 
	 If there are some other optimizations that should be pre-computed before doing the actual import on context, they should be done before returning the importer. */
	func importerForRemoteResults(
		localRepresentations: [GenericLocalDbObject<LocalDb.DbObject, LocalDb.UniquingID, Metadata>],
		rootMetadata: Metadata?,
		uniquingIDsPerEntities: [LocalDb.DbObject.DbEntityDescription: Set<LocalDb.UniquingID>],
		updatedObjectIDsPerEntities: [LocalDb.DbObject.DbEntityDescription: Set<LocalDb.DbObject.DbID>],
		cancellationCheck throwIfCancelled: () throws -> Void
	) throws -> LocalDbImporter
	
}
