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

public protocol DefaultsDisposable: Sendable {
    func dispose()
}

#if !os(Linux)

    /// Observes KVO changes on a `UserDefaults` key. Marked `@unchecked Sendable`
    /// because it stores `didRemoveObserver` mutable state guarded by `lock` and
    /// dispatches the user-provided `handler` on whichever thread KVO fires it on.
    /// The handler closure is `@Sendable` so it can cross isolation boundaries.
    ///
    /// Note: the handler is invoked on whichever thread `UserDefaults` posts the
    /// KVO notification on (typically the writer's thread). Hop to your own
    /// actor or queue inside the handler if you need a specific isolation.
    public final class DefaultsObserver<T: DefaultsSerializable>: NSObject, DefaultsDisposable, @unchecked Sendable where T == T.T, T: Sendable {
        public struct Update {
            public let kind: NSKeyValueChange
            public let indexes: IndexSet?
            public let isPrior: Bool
            public let newValue: T.T?
            public let oldValue: T.T?

            init(dict: [NSKeyValueChangeKey: Any], key: DefaultsKey<T>) {
                // swiftlint:disable:next force_cast
                kind = NSKeyValueChange(rawValue: dict[.kindKey] as! UInt)!
                indexes = dict[.indexesKey] as? IndexSet
                isPrior = dict[.notificationIsPriorKey] as? Bool ?? false
                oldValue = Update.deserialize(dict[.oldKey], for: key) ?? key.defaultValue
                newValue = Update.deserialize(dict[.newKey], for: key) ?? key.defaultValue
            }

            private static func deserialize<U: DefaultsSerializable>(_ value: Any?, for key: DefaultsKey<U>) -> U.T? where U.T == U {
                guard let value = value else { return nil }

                let deserialized = U._defaults.deserialize(value)

                let ret: U.T?
                if key.isOptional, let _deserialized = deserialized, let __deserialized = _deserialized as? OptionalTypeCheck, !__deserialized.isNil {
                    ret = __deserialized as? U.T
                } else if !key.isOptional {
                    ret = deserialized ?? value as? U.T
                } else {
                    ret = value as? U.T
                }

                return ret
            }
        }

        private let key: DefaultsKey<T>
        private let userDefaults: UserDefaults
        private let handler: @Sendable (Update) -> Void
        private let lock = NSLock()
        private var didRemoveObserver = false

        init(key: DefaultsKey<T>, userDefaults: UserDefaults, options: NSKeyValueObservingOptions, handler: @escaping @Sendable (Update) -> Void) {
            self.key = key
            self.userDefaults = userDefaults
            self.handler = handler
            super.init()

            userDefaults.addObserver(self, forKeyPath: key._key, options: options, context: nil)
        }

        deinit {
            dispose()
        }

        // swiftlint:disable:next block_based_kvo
        override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context _: UnsafeMutableRawPointer?) {
            guard let change = change, object != nil, keyPath == key._key else {
                return
            }

            let update = Update(dict: change, key: key)
            handler(update)
        }

        public func dispose() {
            // We use this local property because when you use `removeObserver` when you are
            // not actually observing anymore, you'll receive a runtime error.
            //
            // The lock covers the `removeObserver` call too so that a deinit-triggered
            // `dispose()` racing with an explicit `dispose()` cannot both reach
            // `removeObserver`.
            lock.lock()
            defer { lock.unlock() }
            guard !didRemoveObserver else { return }
            didRemoveObserver = true
            userDefaults.removeObserver(self, forKeyPath: key._key, context: nil)
        }
    }

    extension DefaultsObserver.Update: Sendable {}

#endif
