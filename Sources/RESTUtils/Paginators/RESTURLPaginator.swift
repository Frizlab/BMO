/*
 * RESTURLPaginator.swift
 * BMO
 *
 * Created by François Lamboley on 15/07/2018.
 * Copyright © 2018 happn. All rights reserved.
 */

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
