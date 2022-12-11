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

import CoreData
import Foundation
import os.log

import BMO
import BMO_FastImportRepresentation



final class FastImportRepresentationCoreDataImporter<ResultBuilder : SingleThreadDbRepresentationImporterResultBuilder> : DbRepresentationImporter
	where ResultBuilder.Db == NSManagedObjectContext
{
	
	typealias Db = NSManagedObjectContext
	typealias DbRepresentation = FastImportRepresentation<NSEntityDescription, NSManagedObject, ResultBuilder.DbRepresentationUserInfo>
	
	init(uniquingPropertyName p: String, representations r: [DbRepresentation], resultBuilder rb: ResultBuilder) {
		uniquingPropertyName = p
		resultBuilder = rb
		representations = r
	}
	
	func prepareImport() throws {
		extractUniquingIDs(representations: representations)
	}
	
	func unsafeImport(in db: NSManagedObjectContext, updatingObject updatedObject: Db.Object?) throws -> ResultBuilder.ResultType {
		var objectsByEntityAndUniquingIDs = [NSEntityDescription: [AnyHashable: NSManagedObject]]()
		for (entity, uniquingIDs) in uniquingIDsByEntity {
			let request = NSFetchRequest<NSManagedObject>()
			request.entity = entity
			if db.parent == nil {request.propertiesToFetch = [uniquingPropertyName]} /* If setting propertiesToFetch when context has a parent we get a CoreData exception (corrupt database). Tested on iOS 10. */
			request.predicate = NSPredicate(format: "%K IN %@", uniquingPropertyName, uniquingIDs)
			let objects = try db.fetch(request)
			
			for object in objects {
				guard let uid = object.value(forKey: uniquingPropertyName) as? AnyHashable else {assertionFailure("Well… This is unexpected! Didn't get an AnyHashable value for UID of object \(object) (property name \(uniquingPropertyName))"); continue}
				objectsByEntityAndUniquingIDs[entity, default: [:]][uid] = object
			}
		}
		
		/* The insertedObjects variable is only used to know the objects who need a permanent ID retrieval. */
		var insertedObjects = [NSManagedObject]()
		_ = try unsafeImport(representations: representations, in: db, updatingObject: updatedObject, isRootImport: true, resultBuilder: resultBuilder, prefetchedObjectsByEntityAndUniquingIDs: &objectsByEntityAndUniquingIDs, insertedObjects: &insertedObjects)
		return resultBuilder.result
	}
	
	private func extractUniquingIDs(representations: [DbRepresentation]) {
		for representation in representations {
			assert(!representation.relationships.keys.contains(uniquingPropertyName))
			assert( representation.entity.attributesByName.keys.contains(uniquingPropertyName)) /* attributesByName includes superentities attributes */
			assert(!representation.attributes.keys.contains(uniquingPropertyName) || (representation.attributes[uniquingPropertyName] as? AnyHashable) == representation.uniquingID)
			if let uniquingID = representation.uniquingID {
				uniquingIDsByEntity[representation.entity, default: []].insert(uniquingID)
			}
			for relationshipValueDescription in representation.relationships.values {
				if let relationshipRepresentations = relationshipValueDescription.value?.0 {
					extractUniquingIDs(representations: relationshipRepresentations)
				}
			}
		}
	}
	
	private func unsafeImport(representations: [DbRepresentation], in db: NSManagedObjectContext, updatingObject updatedObject: Db.Object?, isRootImport: Bool, resultBuilder: ResultBuilder, prefetchedObjectsByEntityAndUniquingIDs uniqIDAndEntityToObject: inout [NSEntityDescription: [AnyHashable: NSManagedObject]], insertedObjects: inout [NSManagedObject]) throws -> [Db.Object] {
		if let updatedObject = updatedObject, updatedObject.isUsable {
			guard representations.count <= 1 else {
				throw ImportError.tooManyRepresentationsToUpdateObject
			}
			if let r = representations.first {
				guard updatedObject.entity.isKindOf(entity: r.entity) else {
					throw ImportError.updatedObjectAndRepresentedObjectEntitiesDoNotMatch
				}
				if let uid = r.uniquingID {
					if let currentObjectForUID = uniqIDAndEntityToObject[r.entity]?[uid] {
						if currentObjectForUID != updatedObject {
							/* We’re told to forcibly update an object, but another object has already been created for the given UID.
							 * We must delete the object we were told to update; the caller will have to check whether its object has been deleted before using it. */
							db.delete(updatedObject)
						}
					} else {
						/* We are told to forcibly update an object, and we can do it! */
						let updatedObjectUID = updatedObject.value(forKey: uniquingPropertyName)
						if updatedObjectUID as? AnyHashable != uid {
							if updatedObjectUID != nil {
								/* Object we’re asked to update does not have the same UID as the one we're given in the representation.
								 * We’ll update the UID of the object but print a message in the logs first! */
								if #available(macOS 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {
									BMOConfig.oslog.flatMap{ os_log("Asked to update object %@ but representation has UID %@. Updating UID (property “%{public}@”) of updated object (experimental; might lead to unexpected results).", log: $0, type: .info, updatedObject, String(describing: uid), uniquingPropertyName) }
								}
							}
							updatedObject.setValue(uid, forKey: uniquingPropertyName)
						}
						uniqIDAndEntityToObject[r.entity, default: [:]][uid] = updatedObject
					}
				}
			}
		}
		
		var res = [NSManagedObject]()
		for representation in representations {
			let object: NSManagedObject
			if let uid = representation.uniquingID {
				if let o = uniqIDAndEntityToObject[representation.entity]?[uid] {object = o}
				else {
					/* If the object is not in the uniqIDToObject dictionary we have to create it. */
					object = NSEntityDescription.insertNewObject(forEntityName: representation.entity.name!, into: db)
					object.setValue(uid, forKey: uniquingPropertyName)
					uniqIDAndEntityToObject[representation.entity, default: [:]][uid] = object
					insertedObjects.append(object)
					try resultBuilder.unsafeInserted(object: object, fromDb: db)
				}
			} else if let updatedObject = updatedObject, updatedObject.isUsable {
				/* If there is an updated object but no uniquing the updated object won’t be in the uniqIDToObject dictionary.
				 * We have to treat this case by checking if updatedObject is not nil.
				 * We know we're updating the correct object as the representations array is checked to contain only one element.
				 * (Checked at the beginning of the method.) */
				assert(representations.count == 1)
				object = updatedObject
			} else {
				object = NSEntityDescription.insertNewObject(forEntityName: representation.entity.name!, into: db)
				insertedObjects.append(object)
				try resultBuilder.unsafeInserted(object: object, fromDb: db)
			}
			
			try resultBuilder.unsafeStartedImporting(object: object, inDb: db)
			
			assert(object.entity.isKindOf(entity: representation.entity))
			for (k, v) in representation.attributes {object.setValue(v, forKey: k)}
			
			for (relationshipName, relationshipValue) in representation.relationships {
				let (valueAndMergeType, userInfo) = relationshipValue
				let subBuilder = try resultBuilder.unsafeStartImporting(relationshipName: relationshipName, userInfo: userInfo)
				guard let (value, mergeType) = valueAndMergeType else {
					object.setValue(nil, forKey: relationshipName)
					try subBuilder.unsafeFinishedImport(inDb: db)
					continue
				}
				
				let importedRelationshipValue = try unsafeImport(representations: value, in: db, updatingObject: nil, isRootImport: false, resultBuilder: subBuilder, prefetchedObjectsByEntityAndUniquingIDs: &uniqIDAndEntityToObject, insertedObjects: &insertedObjects)
				let relationship = representation.entity.relationshipsByName[relationshipName]!
				if !relationship.isToMany {
					/* To-one relationship. */
					if !mergeType.isReplace {
						if #available(macOS 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {
							BMOConfig.oslog.flatMap{ os_log("Got merge type %{public}@ for a to-one relationship (%{public}@). Ignoring, using replace.", log: $0, type: .info, String(describing: mergeType), relationshipName) }
						}
					}
					if importedRelationshipValue.count > 1 {
						if #available(macOS 10.12, tvOS 10.0, iOS 10.0, watchOS 3.0, *) {
							BMOConfig.oslog.flatMap{ os_log("Got %d values for a to-one relationship (%{public}@). Taking first value.", log: $0, type: .info, importedRelationshipValue.count, relationshipName) }
						}
					}
					object.setValue(importedRelationshipValue.first, forKey: relationshipName)
				} else {
					/* To-many relationship. */
					let isOrdered = relationship.isOrdered
					switch mergeType {
						case .replace: object.setValue(isOrdered ? NSOrderedSet(array: importedRelationshipValue) : NSSet(array: importedRelationshipValue), forKey: relationshipName)
						case .append:
							if isOrdered {
								let mutableRelationship = object.mutableOrderedSetValue(forKey: relationshipName)
								mutableRelationship.addObjects(from: importedRelationshipValue)
							} else {
								let mutableRelationship = object.mutableSetValue(forKey: relationshipName)
								mutableRelationship.addObjects(from: importedRelationshipValue)
							}
							
						case .insertAtBeginning:
							if isOrdered {
								let mutableRelationship = object.mutableOrderedSetValue(forKey: relationshipName)
								mutableRelationship.insert(importedRelationshipValue, at: IndexSet(integersIn: 0..<importedRelationshipValue.count))
							} else {
								let mutableRelationship = object.mutableSetValue(forKey: relationshipName)
								/* Inserting at the beginning of a non-ordered relationship does not mean much… */
								mutableRelationship.addObjects(from: importedRelationshipValue)
							}
							
						case .custom(mergeHandler: let handler):
							handler(object, relationshipName, importedRelationshipValue)
					}
				}
			}
			try resultBuilder.unsafeFinishedImportingCurrentObject(inDb: db)
			res.append(object)
		}
		if isRootImport {try db.obtainPermanentIDs(for: insertedObjects)}
		try resultBuilder.unsafeFinishedImport(inDb: db)
		return res
	}
	
	private let uniquingPropertyName: String
	
	private let representations: [DbRepresentation]
	private let resultBuilder: ResultBuilder
	
	private var uniquingIDsByEntity = [NSEntityDescription: Set<AnyHashable>]()
	
}
