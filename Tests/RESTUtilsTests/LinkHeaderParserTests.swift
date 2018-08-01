/*
 * LinkHeaderParserTests.swift
 * RESTUtilsTests
 *
 * Straight from https://github.com/Frizlab/LinkHeaderParser
 *
 * Created by François Lamboley on 29/07/2018.
 * Copyright © 2018 happn. All rights reserved.
 */

import XCTest
@testable import RESTUtils



final class LinkHeaderParserTests: XCTestCase {
	
	func testBasicHeaderParse() {
		let header = "<https://apple.com/>; rel=about"
		let expectedLinkValue = LinkValue(link: URL(string: "https://apple.com/")!, context: nil, rel: ["about"], rev: nil, hreflang: nil, mediaQuery: nil, title: nil, type: nil, extensions: [:])
		XCTAssertEqual(LinkHeaderParser.parseLinkHeader(header, defaultContext: nil, contentLanguageHeader: nil, lax: true), [expectedLinkValue])
	}
	
	func testWeirdHeaderParse() {
		let header = "<http://example.com/;;;,,,>; rel=\"next;;;,,, next\"; a-zA-Z0-9!#$&+-.^_|~=!#$%&'*+-.0-9a-zA-Z^_|~; title*=UTF-8'de'N%c3%a4chstes%20Kapitel"
		let expectedLinkValue = LinkValue(link: URL(string: "http://example.com/;;;,,,")!, context: nil, rel: ["next;;;,,,", "next"], rev: nil, hreflang: nil, mediaQuery: nil, title: "Nächstes Kapitel", type: nil, extensions: ["a-za-z0-9!#$&+-.^_|~": ["!#$%&'*+-.0-9a-zA-Z^_|~"]])
		XCTAssertEqual(LinkHeaderParser.parseLinkHeader(header, defaultContext: nil, contentLanguageHeader: nil, lax: true), [expectedLinkValue])
	}
	
	func testInvalidLinkLaxParsing() {
		let header = "<https://api.github.com/users?per_page=21&since=31>; rel=\"next\", <https://api.github.com/users{?since}>; rel=\"first\""
		let expectedLinkValues = [LinkValue(link: URL(string: "https://api.github.com/users?per_page=21&since=31")!, context: nil, rel: ["next"], rev: nil, hreflang: nil, mediaQuery: nil, title: nil, type: nil, extensions: [:])]
		XCTAssertEqual(LinkHeaderParser.parseLinkHeader(header, defaultContext: nil, contentLanguageHeader: nil, lax: true), expectedLinkValues)
	}
	
	func testInvalidLinkStrictParsing() {
		let header = "<https://api.github.com/users?per_page=21&since=31>; rel=\"next\", <https://api.github.com/users{?since}>; rel=\"first\""
		XCTAssertEqual(LinkHeaderParser.parseLinkHeader(header, defaultContext: nil, contentLanguageHeader: nil, lax: false), nil)
	}
	
	static var allTests = [
		("testBasicHeaderParse", testBasicHeaderParse),
		("testWeirdHeaderParse", testWeirdHeaderParse),
		("testInvalidLinkLaxParsing", testInvalidLinkLaxParsing),
		("testInvalidLinkStrictParsing", testInvalidLinkStrictParsing)
	]
	
}
