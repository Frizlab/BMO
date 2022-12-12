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




public protocol BridgeObjectsProtocol<LocalDb, Metadata> {
	
	associatedtype LocalDb : LocalDbProtocol
	associatedtype RemoteDb : RemoteDbProtocol
	
	associatedtype Metadata
	
	var remoteObjects: [RemoteDb.RemoteObject] {get}
	
	var localMetadata: Metadata? {get}
	var localEntity: LocalDb.Object.EntityDescription {get}
	var localMergeType: RelationshipMergeType<LocalDb.Object, LocalDb.Object.RelationshipDescription> {get}
	
	func uniquingID(from remoteObject: RemoteDb.RemoteObject) throws -> AnyHashable?
	func attributes(from remoteObject: RemoteDb.RemoteObject) throws -> [LocalDb.Object.AttributeDescription: Any?]
	func relationships(from remoteObject: RemoteDb.RemoteObject) throws -> [LocalDb.Object.RelationshipDescription: Self?]
	
}
