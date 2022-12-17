// swift-tools-version:5.7
import PackageDescription


let package = Package(
	name: "BMO",
	products: buildArray{
		$0.append(.library(name: "BMO", targets: ["BMO"]))
	},
	dependencies: buildArray{
		$0.append(.package(url: "https://github.com/Frizlab/HasResult.git", from: "1.0.0"))
	},
	targets: buildArray{
		$0.append(.target(name: "BMO", dependencies: buildArray{
			$0.append(.product(name: "HasResult", package: "HasResult"))
		}))
		$0.append(.testTarget(name: "BMOTests", dependencies: ["BMO"]))
	}
)


func buildArray<Element>(of type: Any.Type = Element.self, _ builder: (_ collection: inout [Element]) -> Void) -> [Element] {
	var ret = [Element]()
	builder(&ret)
	return ret
}
