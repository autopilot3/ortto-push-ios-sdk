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
        print("Screen tracking successful: \(response.known)")
        // Or use the backward-compatible property:
        // print("Screen tracking successful: \(response.success)")
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
            print("Screen tracking successful: \(response.known)")
            // Or use the backward-compatible property:
            // print("Screen tracking successful: \(response.success)")
        } else {
            print("Screen tracking completed but no response")
        }
    case .failure(let error):
        print("Screen tracking failed: \(error)")
    }
}
```

### Register Push Token

#### Setting Token First (Required)
Before dispatching push requests, you need to set the token:
```swift
let token = PushToken(value: "device-token-string", type: "apns") // or "fcm"
PushMessaging.shared.token = token
```

#### Async/Await
```swift
do {
    let response = try await Ortto.shared.dispatchPushRequest()
    if let response = response {
        print("Push registration successful: \(response)")
    } else {
        print("Push registration completed but no response")
    }
} catch {
    print("Failed to register push token: \(error)")
}
```

#### Completion Handler
```swift
Ortto.shared.dispatchPushRequest { result in
    switch result {
    case .success(let response):
        if let response = response {
            print("Push registration successful: \(response)")
        } else {
            print("Push registration completed but no response")
        }
    case .failure(let error):
        print("Failed to register push token: \(error)")
    }
}
```

### Complete Push Token Registration Flow

Here's the complete flow for registering a push token:

#### Async/Await
```swift
// 1. Set the token
let token = PushToken(value: "device-token-string", type: "apns")
PushMessaging.shared.token = token

// 2. Dispatch the push request
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
// 1. Set the token
let token = PushToken(value: "device-token-string", type: "apns")
PushMessaging.shared.token = token

// 2. Dispatch the push request
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
- Push token registration requires setting `PushMessaging.shared.token` before calling `dispatchPushRequest()`.
- The `MobileScreenViewResponse` uses `known` property (with a backward-compatible `success` computed property).
