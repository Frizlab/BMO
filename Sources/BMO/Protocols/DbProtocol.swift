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



public protocol DbProtocol {
	
	associatedtype Object
	associatedtype ObjectID : Hashable
	
	associatedtype EntityDescription
	associatedtype FetchRequest
	
	/* Both these methods should be re-entrant. */
	func perform(_ block: @escaping () -> Void)
	func performAndWait(_ block: () throws -> Void) rethrows
	
	func unsafeObjectID(forObject: Object) -> ObjectID
	func unsafeRetrieveExistingObject(fromObjectID: ObjectID) throws -> Object
	
}
