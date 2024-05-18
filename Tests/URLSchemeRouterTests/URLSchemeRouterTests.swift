@testable import URLSchemeRouter
import XCTest

final class URLSchemeRouterTests: XCTestCase {
    func testInputAndOutput() {
        let router = URLSchemeRouter(scheme: "test")

        struct Input: Decodable { let text: String }
        struct Output: Encodable { let text: String }

        router.route("/test") { (input: Input) in
            Output(text: input.text)
        }

        let expectation = expectation(description: "x-success called")
        router.openURL = {
            XCTAssertEqual($0.absoluteString, "success://success?text=hello%20world")
            expectation.fulfill()
        }
        router.handle(URL(string: "test:///test?text=hello%20world&x-success=success%3A%2F%2Fsuccess")!)
        wait(for: [expectation])
    }

    func testInputOnly() {
        let router = URLSchemeRouter(scheme: "test")

        struct Input: Decodable { let text: String }

        router.route("/test") { (_: Input) in }

        let expectation = expectation(description: "x-success called")
        router.openURL = {
            XCTAssertEqual($0.absoluteString, "success://success")
            expectation.fulfill()
        }
        router.handle(URL(string: "test:///test?text=hello%20world&x-success=success%3A%2F%2Fsuccess")!)
        wait(for: [expectation])
    }

    func testOutputOnly() {
        let router = URLSchemeRouter(scheme: "test")

        struct Output: Encodable { let text: String }

        router.route("/test") {
            Output(text: "hello world")
        }

        let expectation = expectation(description: "x-success called")
        router.openURL = {
            XCTAssertEqual($0.absoluteString, "success://success?text=hello%20world")
            expectation.fulfill()
        }
        router.handle(URL(string: "test:///test?x-success=success%3A%2F%2Fsuccess")!)
        wait(for: [expectation])
    }

    func testNoInputOrOutput() {
        let router = URLSchemeRouter(scheme: "test")

        router.route("/test") {}

        let expectation = expectation(description: "x-success called")
        router.openURL = {
            XCTAssertEqual($0.absoluteString, "success://success")
            expectation.fulfill()
        }
        router.handle(URL(string: "test:///test?x-success=success%3A%2F%2Fsuccess")!)
        wait(for: [expectation])
    }

    func testError() {
        let router = URLSchemeRouter(scheme: "test")

        struct Error: Swift.Error, LocalizedError {
            var errorDescription: String? { "Test error" }
        }

        router.route("/test") {
            throw Error()
        }

        let expectation = expectation(description: "x-error called")
        router.openURL = {
            XCTAssertEqual($0.absoluteString, "failure://failure?errorCode=0&errorMessage=Test%20error")
            expectation.fulfill()
        }
        router.handle(URL(string: "test:///test?x-error=failure%3A%2F%2Ffailure")!)
        wait(for: [expectation])
    }

    func testDecodingError() {
        let router = URLSchemeRouter(scheme: "test")

        struct Input: Decodable { let number: Int }

        router.route("/test") { (_: Input) in }

        let expectation = expectation(description: "x-error called")
        router.openURL = {
            XCTAssertEqual($0.absoluteString, "failure://failure?errorCode=0&errorMessage=The%20data%20couldn%E2%80%99t%20be%20read%20because%20it%20isn%E2%80%99t%20in%20the%20correct%20format.")
            expectation.fulfill()
        }
        router.handle(URL(string: "test:///test?number=invalid&x-error=failure%3A%2F%2Ffailure")!)
        wait(for: [expectation])
    }

    func testErrorHandler() {
        let expectation = expectation(description: "onError called")
        let router = URLSchemeRouter(scheme: "test") { error in
            XCTAssertEqual(error as NSError, NSError(domain: "Test error", code: 0))
            expectation.fulfill()
        }

        router.route("/test") { throw NSError(domain: "Test error", code: 0) }
        router.handle(URL(string: "test:///test?number=invalid")!)
        wait(for: [expectation])
    }
}
