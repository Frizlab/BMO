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



public struct Request<LocalDb : LocalDbProtocol, RemoteUserInfo> {
	
	public var localDb: LocalDb
	
	/**
	 The request on the local database.
	 Could be a fetch or a save request, or something else entirely (multiple requests in one, etc.). */
	public var localRequest: LocalDb.DbRequest
	/**
	 Some user info to help the bridge convert the local request to a remote operation.
	 
	 A trivial example of information that could be there would be the fields to retrieve from an API.
	 There are more complex real-life possibilities, of course.
	 
	 One might even put the complete pre-computed remote operation here depending on one’s need. */
	public var remoteUserInfo: RemoteUserInfo
	
	public init(localDb: LocalDb, localRequest: LocalDb.DbRequest, remoteUserInfo: RemoteUserInfo) {
		self.localDb = localDb
		self.localRequest = localRequest
		self.remoteUserInfo = remoteUserInfo
	}
	
}
