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



public protocol RemoteDbProtocol {
	
	/**
	 An operation to do something on the remote db. */
	associatedtype RemoteOperation : Operation & Sendable
	
	/**
	 Will typically be `[String: Any]`, or some kind of `JSON` enum (e.g. [GenericJSON](https://github.com/iwill/generic-json-swift)) if you don’t have the model of your API.
	 If you do, you’ll probably want to make all of the types returned by your API to a common protocol and use this protocol here. */
	associatedtype RemoteObject
	
}
