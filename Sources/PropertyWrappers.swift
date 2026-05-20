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

#if swift(>=5.1)
    public struct SwiftyUserDefaultOptions: OptionSet, Sendable {
        /// Cache the value in memory after the first read.
        ///
        /// Pair with `.observed` so that external writes (other code paths, app
        /// extensions writing through the same suite, or another process) keep
        /// the in-memory cache consistent with `UserDefaults`. Using `.cached`
        /// alone leaves the cache stale after any out-of-band write.
        public static let cached = SwiftyUserDefaultOptions(rawValue: 1 << 0)

        /// Observe `UserDefaults` for changes and update the cached value.
        public static let observed = SwiftyUserDefaultOptions(rawValue: 1 << 2)

        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
    }

    /// Property wrapper for `Defaults`-backed values. Marked `@unchecked Sendable`
    /// because it carries a mutable `_value` cache and `observation` reference
    /// guarded by `lock`. The wrapped getter/setter reads and writes through the
    /// global `Defaults` adapter or one passed at init, both of which delegate to
    /// `UserDefaults` (documented thread-safe).
    ///
    /// `lock` is an `NSRecursiveLock` because the setter holds it across the
    /// `Defaults[key:] = newValue` write, and that write triggers KVO. When
    /// `.observed` is set, the KVO observer callback runs synchronously on the
    /// same thread and re-enters the lock to update the cache. A non-recursive
    /// lock would deadlock in that re-entry path.
    @propertyWrapper
    public final class SwiftyUserDefault<T: DefaultsSerializable>: @unchecked Sendable where T.T == T {
        public let key: DefaultsKey<T>
        public let options: SwiftyUserDefaultOptions

        public var wrappedValue: T {
            get {
                if options.contains(.cached) {
                    lock.lock()
                    let cached = _value
                    lock.unlock()
                    return cached ?? Defaults[key: key]
                } else {
                    return Defaults[key: key]
                }
            }
            set {
                lock.lock()
                defer { lock.unlock() }
                _value = newValue
                Defaults[key: key] = newValue
            }
        }

        private let lock = NSRecursiveLock()
        private var _value: T.T?
        private var observation: (any DefaultsDisposable)?

        public init<KeyStore>(keyPath: KeyPath<KeyStore, DefaultsKey<T>>, adapter: DefaultsAdapter<KeyStore>, options: SwiftyUserDefaultOptions = []) {
            key = adapter.keyStore[keyPath: keyPath]
            self.options = options

            if options.contains(.observed) {
                observation = adapter.observe(key) { [weak self] update in
                    guard let self else { return }
                    self.lock.lock()
                    self._value = update.newValue
                    self.lock.unlock()
                }
            }
        }

        public init(keyPath: KeyPath<DefaultsKeys, DefaultsKey<T>>, options: SwiftyUserDefaultOptions = []) {
            key = Defaults.keyStore[keyPath: keyPath]
            self.options = options

            if options.contains(.observed) {
                observation = Defaults.observe(key) { [weak self] update in
                    guard let self else { return }
                    self.lock.lock()
                    self._value = update.newValue
                    self.lock.unlock()
                }
            }
        }

        deinit {
            observation?.dispose()
        }
    }
#endif
