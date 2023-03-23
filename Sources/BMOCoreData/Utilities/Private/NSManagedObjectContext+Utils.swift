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



internal extension NSManagedObjectContext {
	
	/* If a transient property is modified on an object, the object (and thus the context) is marked as having changes.
	 * This property checks if the only modification in the context is some updated objects that do not have persistent changes. */
	var hasPersistentChanges: Bool {
		guard hasChanges else {
			return false
		}
		guard insertedObjects.isEmpty && deletedObjects.isEmpty else {
			return true
		}
		return updatedObjects.contains{ $0.hasPersistentChangedValues }
	}
	
	/** Returns the error encountered on save if any. */
	@discardableResult
	func saveOrRollback() -> Error? {
		do    {try save(); return nil}
		catch {rollback(); return error}
	}
	
	func saveToDiskOrRollback() {
		do {
			try save()
			
			/* Let's save the parent contexts. */
			guard let parent = parent else {return}
			parent.performAndWait{ parent.saveToDiskOrRollback() }
		} catch {
			rollback()
		}
	}
	
}
