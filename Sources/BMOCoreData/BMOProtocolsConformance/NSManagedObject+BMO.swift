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

@preconcurrency import CoreData
import Foundation

import BMO



extension NSManagedObject : LocalDbObjectProtocol {
	
	public typealias DbID = NSManagedObjectID
	public typealias DbEntityDescription = NSEntityDescription
	
	/* We use String here for two reasons.
	 * First I got wind that NSPropertyDescription should not be used as a key in a dictionary for performance reasons.
	 * Not sure if that’s still true but it makes low-key sense.
	 * Also NSPropertyDescription used to have a critical issue: the hash could be different for two equal NSPropertyDescriptions in some circumstances.
	 * (See <https://gitlab.com/frizlab-demo-projects/nspropertydescription-hash-bug>).
	 * Finally, a String utlimately easier to use than an NSPropertyDescription though it’s less “safe.”
	 * And as we do not need to retrieve the entity bound to the attribute or relationship description, we use a String. */
	public typealias DbAttributeDescription = String
	public typealias DbRelationshipDescription = String
	
}
