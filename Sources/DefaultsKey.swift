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

// MARK: - Static keys

/// Specialize with value type
/// and pass key name to the initializer to create a key.
///
/// Marked `@unchecked Sendable` because `ValueType.T` is an unconstrained
/// associated type that could resolve to a non-`Sendable` value. The stored
/// fields (`_key`, `defaultValue`, `isOptional`) are themselves immutable or
/// trivially `Sendable`, so the cost is the boundary annotation only.
public struct DefaultsKey<ValueType: DefaultsSerializable>: @unchecked Sendable {
    public let _key: String
    public let defaultValue: ValueType.T?
    let isOptional: Bool

    public init(_ key: String, defaultValue: ValueType.T) {
        _key = key
        self.defaultValue = defaultValue
        isOptional = false
    }

    // Couldn't figure out a way of how to pass a nil/none value from extension, thus this initializer.
    // Used for creating an optional key (without defaultValue)
    private init(key: String) {
        _key = key
        defaultValue = nil
        isOptional = true
    }

    @available(*, unavailable, message: "This key needs a `defaultValue` parameter. If this type does not have a default value, consider using an optional key.")
    public init(_: String) {
        fatalError()
    }
}

public extension DefaultsKey where ValueType: DefaultsSerializable, ValueType: OptionalType, ValueType.Wrapped: DefaultsSerializable {
    init(_ key: String) {
        self.init(key: key)
    }

    init(_ key: String, defaultValue: ValueType.T) {
        _key = key
        self.defaultValue = defaultValue
        isOptional = true
    }
}
