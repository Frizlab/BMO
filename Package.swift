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
		var res = [Package.Dependency]()
		res.append(.package(url: "https://github.com/Frizlab/HasResult.git", from: "1.0.0"))
		return res
	}(),
	targets: {
		var res = [Target]()
		res.append(.target(name: "BMO", dependencies: {
			var res = [Target.Dependency]()
			res.append(.product(name: "HasResult", package: "HasResult"))
			return res
		}()))
		res.append(.testTarget(name: "BMOTests", dependencies: ["BMO"]))
		return res
	}()
)
