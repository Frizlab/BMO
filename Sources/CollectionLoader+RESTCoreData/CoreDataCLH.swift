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

import CollectionLoader



@available(macOS 10.12, *)
public protocol CoreDataCLH : CollectionLoaderHelperProtocol where FetchedObjectID == NSManagedObjectID {
	
	associatedtype FetchedObject : NSManagedObject
	
	var resultsController: NSFetchedResultsController<FetchedObject> {get}
	
}


@available(macOS 10.12, *)
public extension CoreDataCLH {
	
	var numberOfCachedObjects: Int {
		return resultsController.fetchedObjects?.count ?? 0
	}
	
	func unsafeCachedObjectID(at index: Int) -> FetchedObjectID {
		return resultsController.fetchedObjects![index].objectID
	}
	
}
