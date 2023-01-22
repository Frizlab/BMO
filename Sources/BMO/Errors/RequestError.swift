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
	
	public enum FailureStep : Sendable {
		
		/**
		 When the error do not come from the normal workflow (e.g. operation is cancelled).
		 
		 When the RequestError has the `none` failure step, the underlying error should be an ``OperationLifecycleError``. */
		case none
		
		case helper_prepareRemoteConversion
		case bridge_getRemoteOperation
		
		case helper_willGoRemote
		case bridge_remoteOperationToObjects
		
		case bridge_remoteToLocalObjects
		case bridge_importerForResults
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
	 The only failure steps where the operation is not retrieved are ``FailureStep-swift.enum/helper_prepareRemoteConversion`` and ``FailureStep-swift.enum/bridge_getRemoteOperation``. */
	public var remoteOperation: Bridge.RemoteDb.RemoteOperation?
	
	/**
	 The local db objects that should have been imported, if they were retrieved. */
	public var genericLocalDbObjects: GenericLocalDbObjects?
	
	public var isCancelledError: Bool {
		return (underlyingError as? OperationLifecycleError) == .cancelled
	}
	
	internal init(failureStep: FailureStep, underlyingError: Error, remoteOperation: Bridge.RemoteDb.RemoteOperation? = nil, genericLocalDbObjects: GenericLocalDbObjects? = nil) {
		self.failureStep = failureStep
		self.underlyingError = underlyingError
		self.remoteOperation = remoteOperation
		self.genericLocalDbObjects = genericLocalDbObjects
	}
	
	internal init(failureStep: FailureStep, checkedUnderlyingError underlyingError: Error, remoteOperation: Bridge.RemoteDb.RemoteOperation? = nil, genericLocalDbObjects: GenericLocalDbObjects? = nil) {
		if let lifecycleError = underlyingError as? OperationLifecycleError {
			self.init(failureStep: .none, lifecycleError: lifecycleError)
		} else {
			self.init(failureStep: failureStep, underlyingError: underlyingError, remoteOperation: remoteOperation, genericLocalDbObjects: genericLocalDbObjects)
		}
	}
	
	internal init(failureStep: FailureStep, lifecycleError: OperationLifecycleError) {
		self.failureStep = failureStep
		self.underlyingError = lifecycleError
		self.remoteOperation = nil
		self.genericLocalDbObjects = nil
	}
	
}
