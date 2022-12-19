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



public struct RequestError<Bridge : BridgeProtocol> : Error {
	
	public enum FailureStep {
		
		case helper_needsRemote
		case bridge_getRemoteOperation
		
		case helper_willGoRemote
		case bridge_remoteOperationToObjects
		
		case bridge_remoteToLocalObjects
		case importer_importPreparation
		case helper_willImport
		case importer_import
		case helper_didImport
		
	}
	
	public typealias GenericLocalDbObjects = [GenericLocalDbObject<Bridge.LocalDb.DbObject, Bridge.LocalDb.UniquingID, Bridge.Metadata>]
	
	public var failureStep: FailureStep
	public var underlyingError: Error
	
	/**
	 The remote operation of the given request if it was retrieved.
	 The only failure steps where the operation is not retrieved are ``FailureStep-swift.enum/helper_needsRemote`` and ``FailureStep-swift.enum/bridge_getRemoteOperation``. */
	public var remoteOperation: Bridge.RemoteDb.RemoteOperation?
	
	/**
	 The local db objects that should have been imported, if they were retrieved. */
	public var genericLocalDbObjects: GenericLocalDbObjects?
	
	internal static func needsRemote(_ underlyingError: Error) -> Self {
		return .init(failureStep: .helper_needsRemote, underlyingError: underlyingError)
	}
	
	internal static func getRemoteOperation(_ underlyingError: Error) -> Self {
		return .init(failureStep: .bridge_getRemoteOperation, underlyingError: underlyingError)
	}
	
	internal static func willGoRemote(_ remoteOperation: Bridge.RemoteDb.RemoteOperation) -> (_ error: Error) -> Self {
		return { .init(failureStep: .helper_willGoRemote, underlyingError: $0, remoteOperation: remoteOperation) }
	}
	
	internal static func remoteOperationToObjects(_ remoteOperation: Bridge.RemoteDb.RemoteOperation) -> (_ error: Error) -> Self {
		return { .init(failureStep: .bridge_remoteOperationToObjects, underlyingError: $0, remoteOperation: remoteOperation) }
	}
	
	internal static func remoteToLocalObjects(_ remoteOperation: Bridge.RemoteDb.RemoteOperation? = nil) -> (_ error: Error) -> Self {
		return { .init(failureStep: .bridge_remoteToLocalObjects, underlyingError: $0, remoteOperation: remoteOperation) }
	}
	
	internal static func importPreparation(_ remoteOperation: Bridge.RemoteDb.RemoteOperation? = nil, genericLocalDbObjects: GenericLocalDbObjects) -> (_ error: Error) -> Self {
		return { .init(failureStep: .importer_importPreparation, underlyingError: $0, remoteOperation: remoteOperation, genericLocalDbObjects: genericLocalDbObjects) }
	}
	
	internal static func willImport(_ remoteOperation: Bridge.RemoteDb.RemoteOperation? = nil, genericLocalDbObjects: GenericLocalDbObjects) -> (_ error: Error) -> Self {
		return { .init(failureStep: .helper_willImport, underlyingError: $0, remoteOperation: remoteOperation, genericLocalDbObjects: genericLocalDbObjects) }
	}
	
	internal static func `import`(_ error: Error, _ remoteOperation: Bridge.RemoteDb.RemoteOperation? = nil, genericLocalDbObjects: GenericLocalDbObjects) -> Self {
		return .init(failureStep: .importer_import, underlyingError: error, remoteOperation: remoteOperation, genericLocalDbObjects: genericLocalDbObjects)
	}
	
	internal static func didImport(_ remoteOperation: Bridge.RemoteDb.RemoteOperation? = nil, genericLocalDbObjects: GenericLocalDbObjects) -> (_ error: Error) -> Self {
		return { .init(failureStep: .helper_didImport, underlyingError: $0, remoteOperation: remoteOperation, genericLocalDbObjects: genericLocalDbObjects) }
	}
	
	internal static func replaceRemoteOperation(_ remoteOperation: Bridge.RemoteDb.RemoteOperation) -> (_ error: Error) -> Error {
		return { error in
			guard var requestError = error as? Self else {
				return error
			}
			requestError.remoteOperation = remoteOperation
			return requestError
		}
	}
	
}
