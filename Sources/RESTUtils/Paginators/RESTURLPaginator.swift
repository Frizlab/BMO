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



public struct RESTURLAndCountPaginatorInfo {
	
	public let url: URL?
	public let count: Int
	
	public init(url u: URL?, count c: Int) {
		url = u
		count = c
	}
	
}


public class RESTURLAndCountPaginator : RESTPaginator {
	
	public let countKey: String
	
	public init(countKey ck: String = "count") {
		countKey = ck
	}
	
	public func forcedRESTPath(withPaginatorInfo info: Any) -> RESTPath? {
		guard let url = (info as? RESTURLAndCountPaginatorInfo)?.url, var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {return nil}
		components.queryItems = components.queryItems?.filter{ item in
			item.name != countKey
		}
		return components.url.flatMap{ .constant($0.absoluteString) }
	}
	
	public func paginationParams(withPaginatorInfo info: Any) -> [String: String]? {
		guard let count = (info as? RESTURLAndCountPaginatorInfo)?.count else {return nil}
		return [countKey: String(count)]
	}
	
}
