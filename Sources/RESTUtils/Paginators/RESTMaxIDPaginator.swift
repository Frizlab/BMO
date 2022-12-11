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

import Foundation



public struct RESTMaxIDPaginatorInfo {
	
	public let maxReachedID: String?
	public let count: Int
	
	public init(maxReachedID i: String?, count c: Int) {
		maxReachedID = i
		count = c
	}
	
}


public class RESTMaxIDPaginator : RESTPaginator {
	
	public let maxReachedIDKey: String
	public let countKey: String
	
	public init(maxReachedIDKey mrik: String, countKey ck: String = "count") {
		maxReachedIDKey = mrik
		countKey = ck
	}
	
	public func forcedRESTPath(withPaginatorInfo: Any) -> RESTPath? {
		return nil
	}
	
	public func paginationParams(withPaginatorInfo info: Any) -> [String: String]? {
		guard let info = info as? RESTMaxIDPaginatorInfo else {return nil}
		
		var ret = [countKey: String(info.count)]
		if let mri = info.maxReachedID {ret[maxReachedIDKey] = mri}
		return ret
	}
	
}
