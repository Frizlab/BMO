// swift-tools-version:5.7
import PackageDescription


let swiftSettings: [SwiftSetting] = []
//let swiftSettings: [SwiftSetting] = [.unsafeFlags(["-Xfrontend", "-warn-concurrency", "-Xfrontend", "-enable-actor-data-race-checks"])]

let package = Package(
	name: "BMO",
	products: [
		.library(name: "BMO", targets: ["BMO"]),
		.library(name: "BMOCoreData", targets: ["BMOCoreData"]),
	],
	targets: [
		.target(name: "BMO", swiftSettings: swiftSettings),
		.testTarget(name: "BMOTests", dependencies: ["BMO"], swiftSettings: swiftSettings),
		
		.target(name: "BMOCoreData", dependencies: [
			.target(name: "BMO"),
		], swiftSettings: swiftSettings),
		.testTarget(name: "BMOCoreDataTests", dependencies: ["BMOCoreData"], swiftSettings: swiftSettings),
	]
)
