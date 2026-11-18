// swift-tools-version: 6.0
import PackageDescription

let names: [String] = ["XML", "HTML", "Markdown", "ECMAScript", "CSS", "Lua", "EBNF"]

let package = Package(
	name: "HooriReal",
	platforms: [.macOS(.v14)],
	dependencies: [
		.package(path: "/Users/fumio/Projects/Spellu/ソース/Spellu"),
	] + names.map { .package(url: "git://git.orion/spellu/\($0)", branch: "develop") },
	targets: [
		.executableTarget(
			name: "hoori-real",
			dependencies: [
				.product(name: "Spellu", package: "Spellu"),
			] + names.map { .product(name: $0, package: $0) },
		),
	]
)
