// swift-tools-version:5.7
import PackageDescription


let package = Package(
	name: "BMO",
	products: {
		var res = [Product]()
		res.append(.library(name: "BMO", targets: ["BMO"]))
		return res
	}(),
	dependencies: {
		let res = [Package.Dependency]()
//		res.append(.package(url: "https://github.com/happn-app/CollectionLoader.git", branch: "dev.tests"))
		return res
	}(),
	targets: {
		var res = [Target]()
		res.append(.target(name: "BMO"))
		res.append(.testTarget(name: "BMOTests", dependencies: ["BMO"]))
		return res
	}()
)
