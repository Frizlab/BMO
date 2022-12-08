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



public protocol BackResultsImporter {
	
	associatedtype Bridge : BridgeProtocol
	
	func retrieveDbRepresentations(fromRemoteRepresentations remoteRepresentations: [Bridge.RemoteObjectRepresentation], expectedEntity entity: Bridge.Db.EntityDescription, userInfo: Bridge.UserInfo, bridge: Bridge, shouldContinueHandler: () -> Bool) throws -> Int
	func createAndPrepareDbImporter(rootMetadata: Bridge.Metadata?) throws
	func unsafeImport(in db: Bridge.Db, updatingObject updatedObject: Bridge.Db.Object?) throws -> ImportBridgeOperationResultsRequestOperation<Bridge>.DbRepresentationImporterResult
	
}


public struct AnyBackResultsImporter<Bridge : BridgeProtocol> : BackResultsImporter {
	
	let retrieveDbRepresentationsHandler: (_ remoteRepresentations: [Bridge.RemoteObjectRepresentation], _ expectedEntity: Bridge.Db.EntityDescription, _ userInfo: Bridge.UserInfo, _ bridge: Bridge, _ shouldContinueHandler: () -> Bool) throws -> Int
	let createAndPrepareDbImporterHandler: (_ rootMetadata: Bridge.Metadata?) throws -> Void
	let unsafeImportHandler: (_ db: Bridge.Db, _ updatedObject: Bridge.Db.Object?) throws -> ImportBridgeOperationResultsRequestOperation<Bridge>.DbRepresentationImporterResult
	
	public init<Importer : BackResultsImporter>(importer: Importer) where Importer.Bridge == Bridge {
		retrieveDbRepresentationsHandler = importer.retrieveDbRepresentations
		createAndPrepareDbImporterHandler = importer.createAndPrepareDbImporter
		unsafeImportHandler = importer.unsafeImport
	}
	
	public func retrieveDbRepresentations(fromRemoteRepresentations remoteRepresentations: [Bridge.RemoteObjectRepresentation], expectedEntity entity: Bridge.Db.EntityDescription, userInfo: Bridge.UserInfo, bridge: Bridge, shouldContinueHandler: () -> Bool) throws -> Int {
		return try retrieveDbRepresentationsHandler(remoteRepresentations, entity, userInfo, bridge, shouldContinueHandler)
	}
	
	public func createAndPrepareDbImporter(rootMetadata: Bridge.Metadata?) throws {
		return try createAndPrepareDbImporterHandler(rootMetadata)
	}
	
	public func unsafeImport(in db: Bridge.Db, updatingObject updatedObject: Bridge.Db.Object?) throws -> ImportBridgeOperationResultsRequestOperation<Bridge>.DbRepresentationImporterResult {
		return try unsafeImportHandler(db, updatedObject)
	}
	
}


public protocol AnyBackResultsImporterFactory {
	
	func createResultsImporter<Bridge : BridgeProtocol>() -> AnyBackResultsImporter<Bridge>?
	
}
