# URLSchemeRouter

With `URLSchemeRouter` you can create a router for your app's URL scheme and add routes, similar to an Express or Hono router in JavaScript. The route input is decoded from the URL query items.

First, create a `URLSchemeRouter`, passing in the scheme you declare in your app's `Info.plist`:

```swift
let router = URLSchemeRouter(scheme: "notesapp")
```

Next, add some routes to your router. Add a route for each action you want to support in your app. Here's an example that will handle the following URL: `notesapp:///search`

> [!NOTE]
> The host component of the URL scheme is ignored. This means `notesapp:///search` is equivalent to `notesapp://x-callback-url/search`

```swift
router.route("/search") {
    print("Navigate to search view")
}
```

Finally, call `router.handle(_:)` when your app receives a URL to trigger the matching route.

```swift
router.handle(url)
```

## Input items

To parse query items from a URL, create a `Decodable` type that matches the items you want to parse. Then, specify in the route handler the type you want to decode. Here's an example for handling `notesapp:///create?title=My%20note`:

```swift
struct Note: Decodable {
    let title: String
    let body: String?
}

router.route("/create") { (note: Note) in
    print("Create note with title: \(note.title), body: \(note.body ?? "empty")")
}
```

## x-callback-url

`URLSchemeRouter` supports [x-callback-url](https://x-callback-url.com/) out of the box, so `x-error` is called if you throw an error in the route handler or input decoding fails, and `x-success` is called on success. You can also return an `Encodable` type in a route handler to pass the output to `x-success`.  

```swift
struct Note: Encodable {
    let title: String
    let body: String?
}

router.route("/fetchNote") {
    let note: Note = try database.fetchNote()
    return note
}
```

When `notesapp:///fetchnotes?x-success=otherapp://` is opened, the router will automatically open `otherapp:///?title=...&body=...`, populating the success parameters from your `Encodable`.

## Errors

Errors thrown from your route handler are automatically passed as paramaters to a specified `x-error` callback. If `x-error` isn't specified, by default `URLSchemeRouter` will do nothing when an error is thrown. To handle errors, you can specify an optional `onError` closure when creating your router. In this example, an alert is shown when `URLSchemeRouter` encounters a decoding issue or error:

```swift
let router = URLSchemeRouter(scheme: "notesapp") { [weak self] error in
    guard let self else { return }
    let alertController = UIAlertController(
        title: error.localizedDescription,
        message: nil,
        preferredStyle: .alert
    )
    alertController.addAction(.init(title: "OK", style: .default))
    window?.rootViewController?.present(
        alertController,
        animated: true
    )
}
```

## Example

In practice, your `URLSchemeRouter` will probably be inside either `scene(_:openURLContexts:)` or `onOpenURL` (SwiftUI). Here's a complete example of how you might handle URLs in an iOS app:

```swift
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo _: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        // App setup code...
    
        for urlContext in connectionOptions.urlContexts {
            handleURL(urlContext.url)
        }
    }
    
    func scene(_: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for context in URLContexts {
            handleURL(context.url)
        }
    }

    func handleURL(_ url: URL) {
        let router = URLSchemeRouter(scheme: "readlaterapp") { [weak self] error in
            guard let self else { return }
            let alertController = UIAlertController(
                title: error.localizedDescription,
                message: nil,
                preferredStyle: .alert
            )
            alertController.addAction(.init(title: "OK", style: .default))
            window?.rootViewController?.present(
                alertController,
                animated: true
            )
        }

        struct SaveParameters: Decodable {
            let url: String
        }
        router.route("/save") { (parameters: SaveParameters) in
            guard let url = URL(string: parameters.url) else {
                struct InvalidURLError: Error, LocalizedError {
                    var errorDescription: String? { "Invalid URL" }
                }
                throw InvalidURLError()
            }
            try database.save(url)
        }

        struct FetchParameters: Encodable {
            let urls: [String]
        }
        router.route("/fetch") {
            return FetchParameters(
                urls: try database.fetchURLs().map(\.absoluteString)
            )
        }

        router.handle(url)
    }
}

```

