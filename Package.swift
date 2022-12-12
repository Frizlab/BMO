// swift-tools-version:5.0
import PackageDescription


let package = Package(
	name: "BMO",
	products: [
		.library(name: "BMO", targets: ["BMO"]),
		.library(name: "RESTUtils", targets: ["RESTUtils"]),
		/* A Library for BMO w/ CoreData and REST. */
		.library(
			name: "Jake",
			targets: ["BMO", "RESTUtils", "BMO+FastImportRepresentation", "BMO+CoreData", "BMO+RESTCoreData", "CollectionLoader+RESTCoreData"]
		)
	],
	dependencies: [
		.package(url: "https://github.com/happn-app/CollectionLoader.git", .branch("dev.tests"))
	],
	targets: [
		.target(name: "BMO2"),
		
		.target(name: "BMO",                           dependencies: []),
		.target(name: "RESTUtils",                     dependencies: []),
		.target(name: "BMO+FastImportRepresentation",  dependencies: ["BMO"]),
		.target(name: "BMO+CoreData",                  dependencies: ["BMO", "BMO+FastImportRepresentation"]),
		.target(name: "BMO+RESTCoreData",              dependencies: ["BMO", "RESTUtils", "BMO+FastImportRepresentation", "BMO+CoreData"]),
		.target(name: "CollectionLoader+RESTCoreData", dependencies: ["CollectionLoader", "BMO", "RESTUtils", "BMO+FastImportRepresentation", "BMO+CoreData", "BMO+RESTCoreData"]),
		.testTarget(name: "BMOTests",                           dependencies: ["BMO"]),
		.testTarget(name: "RESTUtilsTests",                     dependencies: ["RESTUtils"]),
		.testTarget(name: "BMO-FastImportRepresentationTests",  dependencies: ["BMO+FastImportRepresentation"]),
		.testTarget(name: "BMO-CoreDataTests",                  dependencies: ["BMO+CoreData"]),
		.testTarget(name: "BMO-RESTCoreDataTests",              dependencies: ["BMO+RESTCoreData"]),
		.testTarget(name: "CollectionLoader-RESTCoreDataTests", dependencies: ["CollectionLoader+RESTCoreData"])
	]
)
