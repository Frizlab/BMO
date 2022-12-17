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
	
	case success(dbChanges: LocalDbChanges<LocalDbObject, Metadata>, remoteOperation: RemoteOperation)
	
}
