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
		case remoteOperation
		
		case bridge_remoteToLocalObjects
		case helper_willImport
		case importer_import
		case helper_didImport
		
	}
	
	public var failureStep: FailureStep
	public var underlyingError: Error
	
	/**
	 The remote operation of the given request if it was retrieved.
	 The only failure steps where the operation is not retrieved are ``FailureStep-swift.enum/helper_needsRemote`` and ``FailureStep-swift.enum/bridge_getRemoteOperation``. */
	public var remoteOperation: Bridge.RemoteDb.RemoteOperation?
	
	/**
	 The local db objects that should have been imported, if they were retrieved. */
	public var genericLocalDbObjects: [GenericLocalDbObject<Bridge.LocalDb.DbObject, Bridge.LocalDb.UniquingID, Bridge.Metadata>]?
	
}
