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



public enum RequestResult<RemoteOperation : Operation, LocalDbObject : LocalDbObjectProtocol, Metadata : Sendable> {
	
	/**
	 This only happens if the bridge determines no operations were needed for the given request.
	 Example: Update of an object that was not modified. */
	case successNoop
	
	/** Either the bridge or the request helper determined the objects from the remote operation should not be imported in the local db. */
	case successNoopFromRemote(RemoteOperation)
	
	case success(dbChanges: LocalDbChanges<LocalDbObject, Metadata>, remoteOperation: RemoteOperation)
	
}


public extension RequestResult {
	
	var remoteOperation: RemoteOperation? {
		switch self {
			case .successNoop:                                          return nil
			case .successNoopFromRemote(let remoteOp):                  return remoteOp
			case .success(dbChanges: _, remoteOperation: let remoteOp): return remoteOp
		}
	}
	
	var dbChanges: LocalDbChanges<LocalDbObject, Metadata>? {
		switch self {
			case .successNoop, .successNoopFromRemote:                   return nil
			case .success(dbChanges: let dbChanges, remoteOperation: _): return dbChanges
		}
	}
	
}
