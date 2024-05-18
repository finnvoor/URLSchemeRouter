# URLSchemeRouter

With `URLSchemeRouter` you can create a router for your app's URL scheme and add routes. The route input is decoded from the URL query items.

```swift
struct Note: Decodable {
    let title: String
    let body: String
}

let router = URLSchemeRouter(scheme: "notesapp")

router.route("create") { (note: Note) in
    // database.saveNote(
    //     title: note.title,
    //     body: note.body
    // )
}

// In `scene(_:openURLContexts:)` / `onOpenURL`
router.handle(url) // "notesApp://callback/create?title=Title&body=My%20content"
```

`URLSchemeRouter` also supports [x-callback-url](https://x-callback-url.com/) out of the box, so `x-error` is called if you throw an error in the route handler or input decoding fails, and `x-success` is called on success. You can also return an `Encodable` type in a route handler to pass the output to `x-success`.  
