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



public protocol LocalDbObjectProtocol {
	
	associatedtype ID : Hashable & Sendable
	
	associatedtype EntityDescription : Hashable
	associatedtype PropertyDescription : Hashable
	associatedtype RelationshipDescription : Hashable
	
	var entity: EntityDescription {get}
	var unsafeObjectID: ID {get}
	
}


public protocol LocalDbFetchRequestProtocol {
	
	associatedtype EntityDescription : Hashable
	
	var entity: EntityDescription {get}
	
}


public protocol LocalDbProtocol {
	
	associatedtype Object : LocalDbObjectProtocol
	associatedtype FetchRequest : LocalDbFetchRequestProtocol where FetchRequest.EntityDescription == Object.EntityDescription
	
	/* Both these methods should be re-entrant. */
	func perform(_ block: @escaping () -> Void)
	func performAndWait(_ block: () throws -> Void) rethrows
	
	func unsafeRetrieveExistingObject(from objectID: Object.ID) throws -> Object
	
}
