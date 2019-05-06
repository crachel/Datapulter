//
//  Queue.swift
//  Datapulter
//
//  Created by Craig Rachel on 4/13/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//

import UIKit

public final class SynchronizedQueue<Element> {
    
    private var queue: Queue<Element>
    private let accessQueue = DispatchQueue(label: "com.craigrachel.datapulter.synchronizedqueue")
    
    public init() {
        self.queue = Queue()
    }
    
    public func enqueue(_ element: Element) {
        self.accessQueue.async {
            self.queue.enqueue(element)
        }
    }
    
    public func dequeue() -> Element? {
        var element: Element?
        
        self.accessQueue.sync {
            element = queue.dequeue()
        }
        
        return element
    }
    
    public var count: Int {
        var count = 0
        
        self.accessQueue.sync {
            count = self.queue.count
        }
        
        return count
    }
    
    public var isEmpty: Bool {
        var e: Bool!
        
        self.accessQueue.sync {
            e = self.queue.isEmpty
        }
        
        return e
    }
}

/**
 * First-in first-out queue (FIFO)
 * New elements are added to the end of the queue. Dequeuing pulls elements from
 * the front of the queue.
 * Enqueuing and dequeuing are O(1) operations.
 */
public struct Queue<T> {
    
    fileprivate var array = [T?]()
    fileprivate var head = 0
    
    public var isEmpty: Bool {
        return count == 0
    }
    
    public var count: Int {
        return array.count - head
    }
    
    public mutating func enqueue(_ element: T) {
        array.append(element)
    }
    
    public mutating func dequeue() -> T? {
        guard head < array.count, let element = array[head] else { return nil }
        
        array[head] = nil
        head += 1
        
        let percentage = Double(head)/Double(array.count)
        if array.count > 50 && percentage > 0.25 {
            array.removeFirst(head)
            head = 0
        }
        
        return element
    }
    
    public var front: T? {
        if isEmpty {
            return nil
        } else {
            return array[head]
        }
    }
}
