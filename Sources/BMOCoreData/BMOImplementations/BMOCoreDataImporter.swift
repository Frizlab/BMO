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

import CoreData
import Foundation
import os.log

import BMO



public struct BMOCoreDataImporter<LocalDb : LocalDbProtocol, Metadata : Sendable> : LocalDbImporterProtocol
where LocalDb.DbObject == NSManagedObject,
		LocalDb.DbContext == NSManagedObjectContext
{
	
	public typealias GenericLocalDbObject = BMO.GenericLocalDbObject<NSManagedObject, LocalDb.UniquingID, Metadata>
	
	/**
	 The property the importer will use to do the uniquing.
	 Must be an attribute (of any type); NOT a relationship.
	 
	 All of the entities of the objects that will be imported **must** have an attribute that have this name.
	 
	 If a fast import representation has a uniquing id and the uniquing property name is in the attributes of the fast import representation,
	  it will be assert’d that the value of the uniquing property name attribute is equal to the given uniquing id.
	 It is also always asserted that the uniquing property name is NOT in the relationship keys of the representation.
	 
	 Examples:
	 
	     - uniquingPropertyName = "remoteID"
	     - fastImportRepresentation.uniquingID = "42"
	     - fastImportRepresentation.attributes = ["remoteID": "42", "name": "toto"]
	        -> OK
	 
	     - uniquingPropertyName = "remoteID"
	     - fastImportRepresentation.uniquingID = "User/42"
	     - fastImportRepresentation.attributes = ["remoteID": "42", "name": "toto"]
	        -> "User/42" != "42": NOT OK (assertion failure at runtime in debug mode)
	 
	     - uniquingPropertyName = "remoteID"
	     - fastImportRepresentation.uniquingID = 42
	     - fastImportRepresentation.attributes = ["remoteID": "42", "name": "toto"]
	        -> "42" != 42 (type mismatch): NOT OK (assertion failure at runtime in debug mode)
	 
	     - uniquingPropertyName = "zzBID" /* BID for BMO ID, of course! */
	     - fastImportRepresentation.uniquingID = "User/42"
	     - fastImportRepresentation.attributes = ["remoteID": "42", "name": "toto"]
	        -> "zzBID" is not in the keys of the attributes: OK
	 
	     - uniquingPropertyName = "zzBID"
	     - fastImportRepresentation.uniquingID = "User/42"
	     - fastImportRepresentation.attributes = ["remoteID": "42", "name": "toto"]
	     - fastImportRepresentation.relationships = ["zzBID": ...]
	        -> "zzBID" is in the keys of the relationships: NOT OK (assertion failure at runtime in debug mode)
	 */
	public let uniquingProperty: String
	
	public let localRepresentations: [GenericLocalDbObject]
	public let uniquingIDsPerEntities: [NSEntityDescription: Set<LocalDb.UniquingID>]
	
	public let rootMetadata: Metadata?
	
	public init(
		uniquingProperty: String = "zzRID",
		localRepresentations: [GenericLocalDbObject],
		rootMetadata: Metadata?,
		uniquingIDsPerEntities: [NSEntityDescription: Set<LocalDb.UniquingID>],
		cancellationCheck throwIfCancelled: () throws -> Void = { }
	) throws {
		self.uniquingProperty = uniquingProperty
		
		self.localRepresentations = localRepresentations
		self.uniquingIDsPerEntities = uniquingIDsPerEntities
		
		self.rootMetadata = rootMetadata
		
		/* Let’s do some validation on the given local representations. */
		assert(Self.validate(representations: localRepresentations, uniquingProperty: uniquingProperty))
	}
	
	public func onContext_import(in dbContext: NSManagedObjectContext, cancellationCheck throwIfCancelled: () throws -> Void) throws -> LocalDbChanges<LocalDb.DbObject, Metadata> {
		/* First we fetch all the objects that will be updated because their uniquing IDs are updated. */
		var objectsByEntityAndUniquingIDs = [NSEntityDescription: [LocalDb.UniquingID: NSManagedObject]]()
		for (entity, uniquingIDs) in uniquingIDsPerEntities {
			try throwIfCancelled()
			
			let request = NSFetchRequest<NSManagedObject>()
			request.entity = entity
			if dbContext.parent == nil {
				/* If setting propertiesToFetch when context has a parent we get a CoreData exception (corrupt database).
				 * Tested on iOS 10. */
				request.propertiesToFetch = [uniquingProperty]
			}
			request.predicate = NSPredicate(format: "%K IN %@", argumentArray: [uniquingProperty, uniquingIDs])
			let objects = try dbContext.fetch(request)
			
			for object in objects {
				guard let uid = object.value(forKey: uniquingProperty) as? LocalDb.UniquingID else {
					assertionFailure("Invalid CoreData model for BMOCoreDataImporter: Didn't get a \(LocalDb.UniquingID.self) value for UID of object \(object) (property “\(uniquingProperty)”).")
					continue
				}
				objectsByEntityAndUniquingIDs[entity, default: [:]][uid] = object
			}
		}
		
		try throwIfCancelled()
		
		/* Next, let’s do the actual import. */
#warning("TODO: Object update…")
		let changes = try onContext_import(
			representations: localRepresentations,
			metadata: rootMetadata,
			in: dbContext,
			updatingObject: nil,
			prefetchedObjectsByEntityAndUniquingIDs: &objectsByEntityAndUniquingIDs,
			cancellationCheck: throwIfCancelled
		)
		/* Then we retrieve the persistent IDs of all the objects to avoid headaches with NSFetchedResultsController… */
		try dbContext.obtainPermanentIDs(for: Array(changes.insertedDbObjects))
		/* And we’re done. */
		return changes
	}
	
	private static func validate(representations: [GenericLocalDbObject], uniquingProperty: String) -> Bool {
		func validate(representation: GenericLocalDbObject) -> Bool {
			return (
				 !representation.relationships.keys.contains(uniquingProperty) &&
				  representation.entity.attributesByName/*includes superentities attributes*/.keys.contains(uniquingProperty) &&
				(!representation.attributes.keys.contains(uniquingProperty) || (representation.attributes[uniquingProperty] as? LocalDb.UniquingID) == representation.uniquingID) &&
				  representation.relationships.values.compactMap(\.?.value).flatMap{ $0 }.allSatisfy{ validate(representation: $0) }
			)
		}
		return representations.allSatisfy(validate(representation:))
	}
	
	private func onContext_import(
		representations: [GenericLocalDbObject],
		metadata: Metadata?,
		in db: NSManagedObjectContext,
		updatingObject updatedObject: NSManagedObject?,
		prefetchedObjectsByEntityAndUniquingIDs uniqIDAndEntityToObject: inout [NSEntityDescription: [LocalDb.UniquingID: NSManagedObject]],
		cancellationCheck throwIfCancelled: () throws -> Void
	) throws -> LocalDbChanges<NSManagedObject, Metadata> {
		var res = LocalDbChanges<NSManagedObject, Metadata>(metadata: metadata)
		
		if let updatedObject = updatedObject, updatedObject.isUsable {
			guard representations.count <= 1 else {
				throw Err.tooManyRepresentationsToUpdateObject
			}
			if let r = representations.first {
				guard updatedObject.entity.isKindOf(entity: r.entity) else {
					throw Err.updatedObjectAndRepresentedObjectEntitiesDoNotMatch
				}
				if let uid = r.uniquingID {
					if let currentObjectForUID = uniqIDAndEntityToObject[r.entity]?[uid] {
						if currentObjectForUID != updatedObject {
							/* We’re told to forcibly update an object, but another object has already been created for the given UID.
							 * We must delete the object we were told to update; the caller will have to check whether its object has been deleted before using it. */
							db.delete(updatedObject)
							res.deletedDbObjects.insert(updatedObject)
						}
					} else {
						/* We are told to forcibly update an object, and we can do it! */
						let updatedObjectUID = updatedObject.value(forKey: uniquingProperty)
						if updatedObjectUID as? LocalDb.UniquingID != uid {
							if updatedObjectUID != nil {
								/* Object we’re asked to update does not have the same UID as the one we're given in the representation.
								 * We’ll update the UID of the object but print a message in the logs first! */
								if #available(macOS 11.0, tvOS 14.0, iOS 14.0, watchOS 7.0, *) {Logger.importer.warning("Asked to update object \(updatedObject) but representation has UID \(String(describing: uid)). Updating UID (property “\(uniquingProperty, privacy: .public)”) of updated object (experimental; might lead to unexpected results).")}
								else                                                           {os_log("Asked to update object %@ but representation has UID %@. Updating UID (property “%{public}@”) of updated object (experimental; might lead to unexpected results).", log: .importer, type: .info, updatedObject, String(describing: uid), uniquingProperty)}
							}
							updatedObject.setValue(uid, forKey: uniquingProperty)
							res.updatedDbObjects.insert(updatedObject)
						}
						uniqIDAndEntityToObject[r.entity, default: [:]][uid] = updatedObject
					}
				}
			}
		}
		
		for representation in representations {
			try throwIfCancelled()
			
			let object: NSManagedObject
			if let uid = representation.uniquingID {
				if let o = uniqIDAndEntityToObject[representation.entity]?[uid] {
					object = o
					if representation.hasAttributesOrRelationships {
						res.updatedDbObjects.insert(object)
					}
				} else {
					/* If the object is not in the uniqIDToObject dictionary we have to create it. */
					object = NSEntityDescription.insertNewObject(forEntityName: representation.entity.name!, into: db)
					object.setValue(uid, forKey: uniquingProperty)
					uniqIDAndEntityToObject[representation.entity, default: [:]][uid] = object
					res.insertedDbObjects.insert(object)
				}
			} else if let updatedObject = updatedObject, updatedObject.isUsable {
				/* If there is an updated object but no uniquing the updated object won’t be in the uniqIDToObject dictionary.
				 * We have to treat this case by checking if updatedObject is not nil.
				 * We know we're updating the correct object as the representations array is checked to contain only one element.
				 * (Checked at the beginning of the method.) */
				assert(representations.count == 1)
				object = updatedObject
				if representation.hasAttributesOrRelationships {
					res.updatedDbObjects.insert(object)
				}
			} else {
				object = NSEntityDescription.insertNewObject(forEntityName: representation.entity.name!, into: db)
				res.insertedDbObjects.insert(object)
			}
			
			var builtImportedObject = LocalDbChanges<NSManagedObject, Metadata>.ImportedObject(object: object)
			
			assert(object.entity.isKindOf(entity: representation.entity))
			for (k, v) in representation.attributes {
				object.setValue(v as! NSObject?, forKey: k)
			}
			
			for (relationshipName, relationshipValue) in representation.relationships {
				try throwIfCancelled()
				
				guard let (relationshipObjects, mergeType, subMetadata) = relationshipValue else {
					builtImportedObject.modifiedRelationships[relationshipName] = .some(nil)
					object.setValue(nil, forKey: relationshipName)
					continue
				}
				
				let subDbChanges = try onContext_import(
					representations: relationshipObjects,
					metadata: subMetadata,
					in: db,
					updatingObject: nil,
					prefetchedObjectsByEntityAndUniquingIDs: &uniqIDAndEntityToObject,
					cancellationCheck: throwIfCancelled
				)
				builtImportedObject.modifiedRelationships[relationshipName] = subDbChanges
				res.insertedDbObjects.formUnion(subDbChanges.insertedDbObjects)
				res.updatedDbObjects.formUnion(subDbChanges.updatedDbObjects)
				res.deletedDbObjects.formUnion(subDbChanges.deletedDbObjects)
				
				let importedRelationshipValue = subDbChanges.importedObjects.map(\.object)
				
				let relationship = representation.entity.relationshipsByName[relationshipName]!
				if !relationship.isToMany {
					/* To-one relationship. */
					if !mergeType.isReplace {
						if #available(macOS 11.0, tvOS 14.0, iOS 14.0, watchOS 7.0, *) {Logger.importer.info("Got merge type \(String(describing: mergeType), privacy: .public) for a to-one relationship (\(relationshipName, privacy: .public)). Ignoring, using replace.")}
						else                                                           {os_log("Got merge type %{public}@ for a to-one relationship (%{public}@). Ignoring, using replace.", log: .importer, type: .info, String(describing: mergeType), relationshipName)}
					}
					if importedRelationshipValue.count > 1 {
						if #available(macOS 11.0, tvOS 14.0, iOS 14.0, watchOS 7.0, *) {Logger.importer.info("Got \(importedRelationshipValue.count, privacy: .public) values for a to-one relationship (\(relationshipName, privacy: .public)). Taking first value.")}
						else                                                           {os_log("Got %d values for a to-one relationship (%{public}@). Taking first value.", log: .importer, type: .info, importedRelationshipValue.count, relationshipName)}
					}
					object.setValue(importedRelationshipValue.first, forKey: relationshipName)
				} else {
					/* To-many relationship. */
					let isOrdered = relationship.isOrdered
					switch mergeType {
						case .replace:
							object.setValue(
								isOrdered ? NSOrderedSet(array: importedRelationshipValue) : NSSet(array: importedRelationshipValue),
								forKey: relationshipName
							)
							
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
			res.importedObjects.append(builtImportedObject)
		}
		return res
	}
	
}
