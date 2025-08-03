# Making Requests with the Ortto SDK Request Queue

The Ortto iOS SDK now serializes all session-affecting HTTP requests (such as user identification and push token registration) using a centralized async request queue. This ensures that requests are processed in order and prevents race conditions or session ID mismatches.

## Why a Request Queue?

Previously, requests like `identify` and push token registration could run concurrently, potentially causing multiple or disassociated session IDs. The request queue ensures these requests are executed one at a time, preserving session integrity.

## How It Works

- All session-affecting requests are enqueued and executed serially.
- Each request returns a result asynchronously (using Swift's async/await or a completion handler).
- The queue is managed by `OrttoRequestQueue` and is accessible via `Ortto.shared.requestQueue`.

## Usage Examples

### Identify a User

#### Async/Await
```swift
let user = UserIdentifier(/* ... */)
do {
    let sessionID = try await Ortto.shared.identify(user)
    print("Identified with session: \(sessionID)")
} catch {
    print("Failed to identify: \(error)")
}
```

#### Completion Handler
```swift
let user = UserIdentifier(/* ... */)
Ortto.shared.identify(user) { result in
    switch result {
    case .success(let sessionID):
        print("Identified with session: \(sessionID)")
    case .failure(let error):
        print("Failed to identify: \(error)")
    }
}
```

### Track Screen View

#### Async/Await
```swift
do {
    let response = try await Ortto.shared.screen("HomeScreen")
    if let response = response {
        print("Screen tracking successful: \(response.success)")
    } else {
        print("Screen tracking completed but no response")
    }
} catch {
    print("Screen tracking failed: \(error)")
}
```

#### Completion Handler
```swift
Ortto.shared.screen("HomeScreen") { result in
    switch result {
    case .success(let response):
        if let response = response {
            print("Screen tracking successful: \(response.success)")
        } else {
            print("Screen tracking completed but no response")
        }
    case .failure(let error):
        print("Screen tracking failed: \(error)")
    }
}
```

### Register Push Token

#### Async/Await
```swift
let token = PushToken(value: "...", type: .apns)
do {
    let response = try await Ortto.shared.apiManager.sendPushPermission(sessionID: Ortto.shared.userStorage.session, token: token, permission: true)
    print("Push registration response: \(String(describing: response))")
} catch {
    print("Failed to register push token: \(error)")
}
```

#### Completion Handler
```swift
let token = PushToken(value: "...", type: .apns)
Ortto.shared.apiManager.sendPushPermission(sessionID: Ortto.shared.userStorage.session, token: token, permission: true) { response in
    print("Push registration response: \(String(describing: response))")
}
```

### Dispatch Push Request

#### Async/Await
```swift
do {
    let response = try await Ortto.shared.dispatchPushRequest()
    if let response = response {
        print("Push request successful: \(response)")
    } else {
        print("Push request completed but no response")
    }
} catch {
    print("Push request failed: \(error)")
}
```

#### Completion Handler
```swift
Ortto.shared.dispatchPushRequest { result in
    switch result {
    case .success(let response):
        if let response = response {
            print("Push request successful: \(response)")
        } else {
            print("Push request completed but no response")
        }
    case .failure(let error):
        print("Push request failed: \(error)")
    }
}
```

## Notes
- All session-affecting requests are now serialized.
- You can safely call `identify` and push registration methods in any order; the queue will ensure correct sequencing.
- For best results, use the async/await APIs in modern Swift code.
- All methods now properly propagate success/failure results from the queue processing.
- Screen tracking requests are also queued to ensure proper session usage.
