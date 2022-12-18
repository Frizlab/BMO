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

import BMO



extension NSManagedObjectContext : LocalDbContext {
	
	public func performRW(block: @escaping () -> Void) {
		perform(block)
	}
	
	public func performAndWaitRW(_ block: () throws -> Void) rethrows {
		if #available(macOS 12.0, *) {
			try performAndWait(block)
		} else {
			try withoutActuallyEscaping(block, do: { escapableBlock in
				var errorOnContext: Error? = nil
				performAndWait{
					do    {try escapableBlock()}
					catch {errorOnContext = error}
				}
				if let error = errorOnContext {throw error}
			})
		}
	}
	
}
