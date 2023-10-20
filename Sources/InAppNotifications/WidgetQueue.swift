//
//  WidgetQueue.swift
//
//
//  Created by Mitchell Flindell on 17/7/2023.
//

import Foundation

class WidgetQueue {
    private static let orttoWidgetQueueKey = "ortto_widgets_queue"

    private var _queue: [String] {
        get {
            UserDefaults.standard.array(forKey: Self.orttoWidgetQueueKey) as? [String] ?? []
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.orttoWidgetQueueKey)
        }
    }

    func isEmpty() -> Bool {
        _queue.isEmpty
    }

    func queue(_ newId: String) {
        let queue = _queue

        if queue.contains(where: { id in
            id == newId
        }) {
            return
        }

        _queue = [newId] + queue
    }

    func dequeue() -> String? {
        _queue.popLast()
    }

    func peekLast() -> String? {
        _queue.last
    }

    func remove(_ idToRemove: String) {
        let queue = _queue

        _queue = queue.filter { id in
            id != idToRemove
        }
    }
}
