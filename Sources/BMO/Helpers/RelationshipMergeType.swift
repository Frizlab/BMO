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



public enum RelationshipMergeType<Object, Relationship> : Sendable {
	
	case replace
	case append
	case insertAtBeginning
	case custom(@Sendable (_ object: Object, _ relationship: Relationship, _ newValues: [Object]) -> Void)
	
}


public extension RelationshipMergeType {
	
	var isReplace: Bool {
		switch self {
			case .replace: return true
			default:       return false
		}
	}
	
}
