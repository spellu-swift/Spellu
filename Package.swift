// swift-tools-version: 6.0
import PackageDescription
import CompilerPluginSupport


let package = Package(
	name: "Spellu",
	platforms: [
		.macOS(.v14),
		.iOS(.v17),
	],
	products: [
		.library(
			name: "Spellu",
			targets: ["Spellu"],
		),
		.library(
			name: "SpelluRegex",
			targets: ["SpelluRegex"],
		),
	],
	dependencies: [
		.package(id: "spellu.Basis", from: "0.10.0"),
		.package(id: "spellu.UnicodeDatabase", from: "0.10.0"),
		.package(id: "spellu.SwiftSyntax", "600.0.0"..<"700.0.0"),
	],
	targets: [
		.target(
			name: "Spellu",
			dependencies: [
				"SpelluCore",
				"SpelluInterpreter",
				"SpelluMikazuchi",
				"SpelluSakuya",
				"SpelluHoori",
			],
		),
		.target(
			name: "SpelluRegex",
			dependencies: [
				"Spellu",
				.product(name: "UnicodeDatabase", package: "spellu.UnicodeDatabase"),
			],
		),
		.target(
			name: "SpelluCore",
			dependencies: [
				.product(name: "Basis", package: "spellu.Basis"),
				"SpelluLex",
				"SpelluMacros",
			],
		),
		.target(
			name: "SpelluLex",
			dependencies: [
				.product(name: "Basis", package: "spellu.Basis"),
				.product(name: "UnicodeDatabase", package: "spellu.UnicodeDatabase"),
			],
		),
		.target(
			name: "SpelluInterpreter",
			dependencies: [
				.product(name: "Basis", package: "spellu.Basis"),
				"SpelluCore",
				"SpelluLex",
			],
		),
		.target(
			name: "SpelluMikazuchi",
			dependencies: [
				"SpelluCore",
				"SpelluLex",
			],
		),
		.target(
			name: "SpelluSakuya",
			dependencies: [
				.product(name: "Basis", package: "spellu.Basis"),
				"SpelluCore",
				"SpelluLex",
			],
		),
		.target(
			name: "SpelluHoori",
			dependencies: [
				.product(name: "Basis", package: "spellu.Basis"),
				"SpelluCore",
				"SpelluLex",
			],
		),
		.macro(
			name: "SpelluMacros",
			dependencies: [
				.product(name: "SwiftSyntax", package: "spellu.SwiftSyntax"),
			],
		),

		.testTarget(
			name: "SpelluTests",
			dependencies: [
				"Spellu",
				.product(name: "Testing", package: "spellu.Basis"),
			],
		),
		.testTarget(
			name: "SpelluRegexTests",
			dependencies: [
				"SpelluRegex",
				"SpelluCore",
				.product(name: "Testing", package: "spellu.Basis"),
			],
		),
		.testTarget(
			name: "SpelluCoreTests",
			dependencies: [
				"SpelluCore",
				.product(name: "Testing", package: "spellu.Basis"),
			],
		),
		.testTarget(
			name: "SpelluLexTests",
			dependencies: [
				"SpelluLex",
				.product(name: "Testing", package: "spellu.Basis"),
			],
		),
		.testTarget(
			name: "SpelluInterpreterTests",
			dependencies: [
				"SpelluInterpreter",
				.product(name: "Testing", package: "spellu.Basis"),
			],
		),
		.testTarget(
			name: "SpelluMikazuchiTests",
			dependencies: [
				"SpelluMikazuchi",
				.product(name: "Testing", package: "spellu.Basis"),
			],
		),
		.testTarget(
			name: "SpelluSakuyaTests",
			dependencies: [
				"SpelluSakuya",
				.product(name: "Testing", package: "spellu.Basis"),
			],
		),
		.testTarget(
			name: "SpelluHooriTests",
			dependencies: [
				"SpelluHoori",
				.product(name: "Testing", package: "spellu.Basis"),
			],
		),
		.testTarget(
			name: "SpelluMacrosTests",
			dependencies: [
				"SpelluMacros",
				.product(name: "Testing", package: "spellu.Basis"),
			],
		),
		.testTarget(
			name: "SpelluBenchmarkTests",
			dependencies: [
				"Spellu",
				"SpelluRegex",
				.product(name: "Testing", package: "spellu.Basis"),
			],
		),
		.testTarget(
			name: "SpelluCompatibleTests",
			dependencies: [
				"Spellu",
				.product(name: "Testing", package: "spellu.Basis"),
			],
		),
	],
)
