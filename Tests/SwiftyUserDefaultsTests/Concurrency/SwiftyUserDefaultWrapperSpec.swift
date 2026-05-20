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

/// Key store used by the SwiftyUserDefault property wrapper specs.
final class WrapperSpecKeys: DefaultsKeyStore, @unchecked Sendable {
    let counter = DefaultsKey<Int>("wrapper.counter", defaultValue: 0)
    let label = DefaultsKey<String>("wrapper.label", defaultValue: "")
}

/// A class that uses the @SwiftyUserDefault property wrapper. Declared at
/// file scope so the wrapper observer's `[weak self]` capture has a stable
/// owner across test cases.
final class WrapperHost: @unchecked Sendable {
    static let keyStore = WrapperSpecKeys()
    nonisolated(unsafe) static var sharedAdapter: DefaultsAdapter<WrapperSpecKeys>!

    @SwiftyUserDefault(keyPath: \WrapperSpecKeys.counter, adapter: WrapperHost.sharedAdapter, options: [.cached, .observed])
    var counter: Int

    @SwiftyUserDefault(keyPath: \WrapperSpecKeys.label, adapter: WrapperHost.sharedAdapter, options: [])
    var label: String
}

/// The wrapper's getter/setter route through the global `Defaults`, so the
/// specs rebind it to a per-test `UserDefaults` suite.
private func rebindGlobalDefaults(to userDefaults: UserDefaults) {
    Defaults = DefaultsAdapter(defaults: userDefaults, keyStore: DefaultsKeys())
}

/// Exercises the SwiftyUserDefault property wrapper under concurrent access
/// and verifies the lock change (NSLock → NSRecursiveLock) closes the
/// cache/storage interleave window opened by the migration's initial lock.
final class SwiftyUserDefaultWrapperSpec: QuickSpec {
    override func spec() {
        var userDefaults: UserDefaults!

        beforeEach {
            userDefaults = UserDefaults(suiteName: UUID().uuidString)!
            userDefaults.cleanObjects()
            WrapperHost.sharedAdapter = DefaultsAdapter(defaults: userDefaults, keyStore: WrapperHost.keyStore)
            rebindGlobalDefaults(to: userDefaults)
        }

        afterEach {
            // Other specs assume `Defaults` points at `UserDefaults.standard`.
            rebindGlobalDefaults(to: .standard)
        }

        describe("@SwiftyUserDefault setter") {
            then("setting via wrapper writes through to UserDefaults") {
                let host = WrapperHost()
                host.counter = 7

                expect(userDefaults.integer(forKey: WrapperHost.keyStore.counter._key)) == 7
            }

            then("getter reflects external writes when .observed is set") {
                let host = WrapperHost()
                userDefaults[WrapperHost.keyStore.counter] = 42

                expect(host.counter).toEventually(equal(42))
            }

            then("concurrent setters with distinct values leave cache and storage in agreement") {
                let host = WrapperHost()

                // Each thread writes its own distinct value. With a missing or
                // half-scoped lock the cache and on-disk value can end up
                // pointing at different writers. With the NSRecursiveLock fix
                // (lock held across both writes) they must agree, whatever
                // the winning value is.
                DispatchQueue.concurrentPerform(iterations: 200) { i in
                    host.counter = i + 1
                }

                // Let any in-flight KVO callbacks settle before sampling.
                Thread.sleep(forTimeInterval: 0.05)

                let finalCache = host.counter
                let finalStorage = userDefaults.integer(forKey: WrapperHost.keyStore.counter._key)
                expect(finalCache) == finalStorage
                expect(finalCache) >= 1
                expect(finalCache) <= 200
            }

            then("concurrent read and write does not crash") {
                let host = WrapperHost()
                let reads = Locked<Int>(0)

                DispatchQueue.concurrentPerform(iterations: 100) { i in
                    if i.isMultiple(of: 2) {
                        host.counter = i
                    } else {
                        _ = host.counter
                        reads.value += 1
                    }
                }

                expect(reads.value) > 0
            }
        }

        describe("@SwiftyUserDefault with .cached + .observed") {
            then("cache is populated by the observer when an external writer updates the key") {
                let host = WrapperHost()
                _ = host.counter

                userDefaults[WrapperHost.keyStore.counter] = 123

                expect(host.counter).toEventually(equal(123), timeout: 2)
            }
        }
    }
}
