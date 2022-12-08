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



public protocol BackResultsImporter<Bridge> {
	
	associatedtype Bridge : BridgeProtocol
	
	func retrieveDbRepresentations(from remoteRepresentations: [Bridge.RemoteObjectRepresentation], expectedEntity entity: Bridge.Db.EntityDescription, userInfo: Bridge.UserInfo, bridge: Bridge, shouldContinueHandler: () -> Bool) throws -> Int
	func createAndPrepareDbImporter(rootMetadata: Bridge.Metadata?) throws
	func unsafeImport(in db: Bridge.Db, updatingObject updatedObject: Bridge.Db.Object?) throws -> ImportBridgeOperationResultsRequestOperation<Bridge>.DbRepresentationImporterResult
	
}


public protocol AnyBackResultsImporterFactory {
	
	func createResultsImporter<Bridge : BridgeProtocol>() -> (any BackResultsImporter<Bridge>)?
	
}
