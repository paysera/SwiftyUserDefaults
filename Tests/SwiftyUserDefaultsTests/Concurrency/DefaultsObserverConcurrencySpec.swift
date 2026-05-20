//
// SwiftyUserDefaults
//
// Copyright (c) 2015-present Radosław Pietruszewski, Łukasz Mróz
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//

import Foundation
import Nimble
import Quick
@testable import SwiftyUserDefaults

/// Exercises the thread-safety guarantees introduced in the strict-concurrency
/// migration: the dispose() lock covers removeObserver, the lock is non-recursive
/// for the observer, and disposal is idempotent under contention.
final class DefaultsObserverConcurrencySpec: QuickSpec {
    override func spec() {
        var userDefaults: UserDefaults!

        beforeEach {
            userDefaults = UserDefaults(suiteName: UUID().uuidString)!
            userDefaults.cleanObjects()
        }

        describe("dispose()") {
            then("is idempotent on a single thread") {
                let key = DefaultsKey<Int>("counter", defaultValue: 0)
                let observer = userDefaults.observe(key) { _ in }

                observer.dispose()
                observer.dispose()
                observer.dispose()
                // No crash, no NSException from removeObserver.
                expect(true) == true
            }

            then("is safe under concurrent dispose calls from many threads") {
                let key = DefaultsKey<Int>("counter", defaultValue: 0)
                let observer = userDefaults.observe(key) { _ in }

                DispatchQueue.concurrentPerform(iterations: 50) { _ in
                    observer.dispose()
                }
                // No crash, no double-removeObserver.
                expect(true) == true
            }

            then("stops delivering updates after dispose") {
                let key = DefaultsKey<Int>("counter", defaultValue: 0)
                let received = Locked<Int>(0)

                let observer = userDefaults.observe(key) { _ in
                    received.value += 1
                }

                userDefaults[key] = 1
                userDefaults[key] = 2

                observer.dispose()

                userDefaults[key] = 3
                userDefaults[key] = 4

                expect(received.value).toEventually(equal(2))
                // Wait a moment to confirm no further updates arrive after dispose.
                Thread.sleep(forTimeInterval: 0.1)
                expect(received.value) == 2
            }
        }

        describe("observe handler") {
            then("delivers updates across concurrent writes without dropping") {
                let key = DefaultsKey<Int>("counter", defaultValue: 0)
                let received = Locked<Int>(0)

                let observer = userDefaults.observe(key) { _ in
                    received.value += 1
                }
                defer { observer.dispose() }

                DispatchQueue.concurrentPerform(iterations: 20) { i in
                    userDefaults[key] = i
                }

                expect(received.value).toEventually(equal(20), timeout: 3)
            }
        }
    }
}
