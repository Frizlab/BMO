// swift-tools-version:5.10
import PackageDescription


//let swiftSettings: [SwiftSetting] = []
let swiftSettings: [SwiftSetting] = [.enableExperimentalFeature("StrictConcurrency")]

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
