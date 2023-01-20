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



extension NSManagedObjectContext : LocalDbContextProtocol {
	
	public func performRW(_ block: @escaping () -> Void) {
		perform(block)
	}
	
	public func performAndWaitRW<T>(_ block: () throws -> T) rethrows -> T {
		if #available(macOS 12, iOS 15, tvOS 16, watchOS 8, *) {
			return try performAndWait(block)
		} else {
			return try withoutActuallyEscaping(block, do: { escapableBlock in
				var retOnContext: Result<T, Error>? = nil
				performAndWait{
					do    {retOnContext = .success(try escapableBlock())}
					catch {retOnContext = .failure(error)}
				}
				return try retOnContext!.get()
			})
		}
	}
	
}
