import Foundation
import URLQueryItemCoder
#if canImport(UIKit)
import UIKit
#elseif canImport(Cocoa)
import Cocoa
#endif

// MARK: - URLSchemeRouter

public class URLSchemeRouter {
    // MARK: Lifecycle

    /// Creates a URLSchemeRouter
    /// - Parameters:
    ///   - scheme: The scheme to match. This should also be declared in your app's `Info.plist` file.
    ///   - errorHandler: An optional error handler to call when x-error isn't specified for a URL and an error occurs.
    ///   - queryItemDecodingStrategies: The strategies for decoding `Decodable` values from the URL query items.
    public init(
        scheme: String,
        onError errorHandler: ((Error) -> Void)? = nil,
        queryItemDecodingStrategies: DecodingStrategies = .default
    ) {
        self.scheme = scheme
        self.errorHandler = errorHandler
        decoder = URLQueryItemDecoder(strategies: queryItemDecodingStrategies)
        #if canImport(UIKit)
        openURL = { UIApplication.shared.open($0) }
        #elseif canImport(Cocoa)
        openURL = { NSWorkspace.shared.open($0) }
        #else
        openURL = { _ in }
        #endif
    }

    // MARK: Public

    /// The scheme that the router matches.
    public let scheme: String

    /// Adds a route handler.
    /// - Parameters:
    ///   - path: The path to match.
    ///   - handler: A handler to call when a URL path matches the specified path.
    public func route<Input: Decodable>(_ path: String, _ handler: @escaping (Input) throws -> (some Encodable)) {
        routes.append(Route(
            path: path,
            inputType: Input.self,
            handler: { try handler($0 as! Input) }
        ))
    }

    /// Adds a route handler.
    /// - Parameters:
    ///   - path: The path to match.
    ///   - handler: A handler to call when a URL path matches the specified path.
    public func route<Input: Decodable>(_ path: String, _ handler: @escaping (Input) throws -> Void) {
        routes.append(Route(
            path: path,
            inputType: Input.self,
            handler: { try handler($0 as! Input) }
        ))
    }

    /// Adds a route handler.
    /// - Parameters:
    ///   - path: The path to match.
    ///   - handler: A handler to call when a URL path matches the specified path.
    public func route(_ path: String, _ handler: @escaping () throws -> (some Encodable)) {
        routes.append(Route(
            path: path,
            inputType: nil,
            handler: { _ in try handler() }
        ))
    }

    public func route(_ path: String, _ handler: @escaping () throws -> Void) {
        routes.append(Route(
            path: path,
            inputType: nil,
            handler: { _ in try handler() }
        ))
    }

    /// Routes a URL.
    /// - Parameter url: The URL to route.
    /// - Returns: Whether or not the url was handled. URLs with a scheme that does not match the router's scheme will not be handled.
    @discardableResult public func handle(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == scheme else {
            return false
        }

        let queryItems = components.queryItems ?? []

        struct XCallback: Decodable {
            let xSuccess: String?
            let xError: String?

            enum CodingKeys: String, CodingKey {
                case xSuccess = "x-success"
                case xError = "x-error"
            }
        }

        let xCallback = try? decoder.decode(XCallback.self, from: queryItems)

        func onSuccess(queryItems: [URLQueryItem] = []) {
            guard var xSuccess = xCallback?.xSuccess.flatMap(URLComponents.init(string:)) else { return }
            for queryItem in queryItems {
                xSuccess.queryItems = (xSuccess.queryItems ?? []) + [queryItem]
            }
            if let url = xSuccess.url { openURL(url) }
        }

        func onError(_ error: Error) {
            guard var xError = xCallback?.xError.flatMap(URLComponents.init(string:)) else {
                errorHandler?(error)
                return
            }
            xError.queryItems = (xError.queryItems ?? []) + [
                URLQueryItem(name: "errorCode", value: "0"),
                URLQueryItem(name: "errorMessage", value: error.localizedDescription)
            ]
            if let url = xError.url { openURL(url) }
        }

        for route in routes {
            if components.path == route.path {
                do {
                    let input: Any
                    if let inputType = route.inputType {
                        do {
                            input = try decoder.decode(inputType, from: queryItems)
                        } catch let error as Swift.DecodingError {
                            throw DecodingError(decodingError: error)
                        } catch {
                            throw error
                        }
                    } else {
                        input = ()
                    }
                    let output = try route.handler(input)
                    if let output = output as? Encodable {
                        onSuccess(
                            queryItems: (try? URLQueryItemEncoder().encode(output)) ?? []
                        )
                    } else {
                        onSuccess()
                    }
                } catch {
                    onError(error)
                }
            }
        }

        return true
    }

    // MARK: Internal

    var openURL: (URL) -> Void

    // MARK: Private

    private struct Route {
        let path: String
        let inputType: Decodable.Type?
        let handler: (Any) throws -> (Any)
    }

    private let errorHandler: ((Error) -> Void)?
    private let decoder: URLQueryItemDecoder

    private var routes: [Route] = []
}

// MARK: URLSchemeRouter.DecodingError

public extension URLSchemeRouter {
    struct DecodingError: Error, LocalizedError {
        public let decodingError: Swift.DecodingError

        public var errorDescription: String? {
            switch decodingError {
            case let Swift.DecodingError.valueNotFound(_, context):
                "Required value for parameter \"\(context.codingPath.map(\.stringValue).joined(separator: "."))\" not found."
            case let Swift.DecodingError.keyNotFound(key, _):
                "Required parameter \"\(key.stringValue)\" not found."
            case let Swift.DecodingError.typeMismatch(_, context):
                "Value for parameter \"\(context.codingPath.map(\.stringValue).joined(separator: "."))\" has incorrect type."
            default: decodingError.localizedDescription
            }
        }
    }
}
