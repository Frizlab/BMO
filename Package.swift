// swift-tools-version:5.7
import PackageDescription


let package = Package(
	name: "BMO",
	products: [
		.library(name: "BMO", targets: ["BMO"])
	],
	dependencies: [
//		.package(url: "https://github.com/happn-app/CollectionLoader.git", .branch("dev.tests"))
	],
	targets: [
		.target(name: "BMO"),
		.testTarget(name: "BMOTests", dependencies: ["BMO"])
	]
)
