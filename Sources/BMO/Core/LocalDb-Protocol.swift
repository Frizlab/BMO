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



public protocol LocalDbContext {
	
	/* We do not need that in BMO. */
//	func performRO( block: @escaping () -> Void)
//	func performAndWaitRO(_ block: @escaping () throws -> Void) rethrows
	
	func performRW( block: @escaping () -> Void)
	func performAndWaitRW(_ block: () throws -> Void) rethrows
	
}


public protocol LocalDbObjectProtocol {
	
	associatedtype DbID : Hashable & Sendable
	
	associatedtype DbEntityDescription : Hashable & Sendable
	associatedtype DbAttributeDescription : Hashable & Sendable
	associatedtype DbRelationshipDescription : Hashable & Sendable
	
}


public protocol LocalDbProtocol {
	
	associatedtype DbContext : LocalDbContext
	
	associatedtype DbObject : LocalDbObjectProtocol
	associatedtype DbRequest
	
	associatedtype UniquingID : Hashable & Sendable
	
	var context: DbContext {get}
	
}
