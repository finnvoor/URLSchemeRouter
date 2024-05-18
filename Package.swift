// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "URLSchemeRouter",
    platforms: [.iOS(.v13), .macOS(.v10_15), .tvOS(.v13)],
    products: [.library(name: "URLSchemeRouter", targets: ["URLSchemeRouter"])],
    dependencies: [.package(url: "https://github.com/kylehughes/URLQueryItemCoder.git", from: "1.0.0")],
    targets: [
        .target(
            name: "URLSchemeRouter",
            dependencies: [.product(name: "URLQueryItemCoder", package: "URLQueryItemCoder")]
        ),
        .testTarget(name: "URLSchemeRouterTests", dependencies: ["URLSchemeRouter"])
    ]
)
