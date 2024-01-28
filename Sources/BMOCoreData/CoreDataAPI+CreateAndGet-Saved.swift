/*
Copyright 2023 happn

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License. */

import CoreData
import Foundation

import BMO



public extension CoreDataAPI {
	
	@discardableResult
	func createAndGet<Object : NSManagedObject>(
		_ objectType: Object.Type = Object.self,
		requestUserInfo: Bridge.RequestUserInfo? = nil,
		settings: Settings? = nil,
		autoStart: Bool = true,
		savedObjectCreator: @escaping @Sendable (_ managedObjectContext: NSManagedObjectContext) throws -> Object,
		handler: @escaping @Sendable @MainActor (Result<(createdObject: Object, results: Bridge.RequestResults), Error>) -> Void = { _ in }
	) throws -> RequestOperation<Bridge> {
		return try create(objectType, requestUserInfo: requestUserInfo, settings: settings, autoStart: autoStart, savedObjectCreator: savedObjectCreator, handler: { results in
			do {
				let result = try results.get()
				guard let importedObjects = result.dbChanges?.importedObjects,
						let createdObject = importedObjects.first?.object as? Object,
						importedObjects.count == 1
				else {
					throw Err.creationRequestResultDoesNotContainObject
				}
				handler(.success((createdObject, result)))
			} catch {
				handler(.failure(error))
			}
		})
	}
	
	@discardableResult
	@available(macOS 10.15, tvOS 13, iOS 13, watchOS 6, *)
	func createAndGet<Object : NSManagedObject>(
		_ objectType: Object.Type = Object.self,
		requestUserInfo: Bridge.RequestUserInfo? = nil,
		settings: Settings? = nil,
		savedObjectCreator: @escaping @Sendable (_ managedObjectContext: NSManagedObjectContext) throws -> Object
	) async throws -> (createdObject: Object, results: Bridge.RequestResults) {
		return try await withCheckedThrowingContinuation{ continuation in
			do {
				try createAndGet(
					objectType,
					requestUserInfo: requestUserInfo,
					settings: settings, autoStart: true,
					savedObjectCreator: savedObjectCreator,
					handler: { res in
						continuation.resume(with: res)
					}
				)
			} catch {
				continuation.resume(throwing: error)
			}
		}
	}
	
}
