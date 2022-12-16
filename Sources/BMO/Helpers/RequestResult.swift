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



public enum RequestResult<RemoteOperation : Operation, LocalDbObject : LocalDbObjectProtocol, Metadata : Hashable & Sendable> {
	
	/**
	 This only happens if the bridge determines no operations were needed for the given request.
	 Example: Update of an object that was not modified. */
	case successNoop
	
	/**
	 This happens when there was a remote operation for the request, but it failed.
	 Nothing more happens after the remote operation fails. */
	case failureOfRemoteOperation(Error, remoteOperation: RemoteOperation)
	
	/**
	 The remote operation was returned for the given request, it succeeded, but its results could not be converted to a local db representation. */
	case failureOfRemoteToLocalBridge(Error, succeededRemoteOperation: RemoteOperation)
	
	/**
	 Everything went well, except for the last step: the import of the local db representation to the actual db. */
	case failureOfImport(Error, succeededRemoteOperation: RemoteOperation)
	
	case success(dbChanges: LocalDbChanges<LocalDbObject, Metadata>, remoteOperation: RemoteOperation)
	
}
