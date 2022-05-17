# Kodable

[![Build Status][build status badge]][build status]
[![codebeat badge][codebeat status badge]][codebeat status]
[![codecov][codecov status badge]][codecov status]
![Platforms][platforms badge]

`Kodable` is an extension of the `Codable` functionality through property wrappers. The main goal is to remove boilerplate while also adding useful functionality. 

**Features:**
- No need to write your own `init(from decoder: Decoder)` or `CodingKeys` 
- Provide a custom key for decoding
- Access nested values using the `.` notation
- Add a default value in case the value is missing
- Overriding the values decoded (i.e. trimming a string)
- Validation of the values decoded
- Automatically tries to decode `String` and `Bool` from other types as a fallback 
- Transformer protocol to implement your own additional functionality on top of the existing ones
- Special error handling and better readability of Swift's `DecodingError`


Table of contents
=================

<!--ts-->

   * [Kodable](#kodable)
   * [Table of contents](#table-of-contents)
      * [Installation](#installation)
         * [Swift Package Manager](#swift-package-manager)
      * [Usage](#usage)
         * [Provided Wrappers](#provided-wrappers)
            * [Coding](#coding)
            * [CodableDate](#codabledate)
      * [Advanced Usage](#advanced-usage)
         * [Lossy Type Decoding](#lossy-type-decoding)
            * [Array](#array)
            * [Bool](#bool)
            * [String](#string)
         * [Overriding Values](#overriding-values)
         * [Validating Values](#validating-values)
         * [Custom Wrapper](#custom-wrapper)
         * [Encode null values](#encode-null-values)
      * [Debugging](#debugging)
      * [Contributions](#contributions)
      * [License](#license)
      * [Contact](#contact)

<!-- Added by: jarmourato, at: Mon Dec 28 12:22:31 WET 2020 -->

<!--te-->


## Installation

### Swift Package Manager

If you're working directly in a Package, add Kodable to your Package.swift file

```swift
dependencies: [
    .package(url: "https://github.com/JARMourato/Kodable.git", .upToNextMajor(from: "1.1.0")),
]
```

If working in an Xcode project select `File->Swift Packages->Add Package Dependency...` and search for the package name: `Kodable` or the git url:

`https://github.com/JARMourato/Kodable.git`


## Usage


### Provided Wrappers

#### Coding

Just make your type conform to `Kodable` and you'll have access to all of the features `Coding` brings. 
You can mix and match `Codable` values with `Coding` properties. 

Declare your model:

```Swift
struct User: Kodable {
    var identifier: String = ""
    var social: String?
    @Coding("first_name") var firstName: String
    @Coding(default: "+1 123456789") var phone: String
    @Coding("address.zipCode") var zipCode: Int
}

// Instead of

struct CodableUser: Codable {

    enum Keys: String, CodingKey {
        case identifier, social, firstName = "first_name", phone, address
    }

    enum NestedKeys: String, CodingKey {
        case zipCode
    }

    var identifier: String = ""
    var social: String?
    var firstName: String
    var phone: String
    var zipCode: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        identifier = try container.decode(String.self, forKey: .identifier)
        social = try container.decodeIfPresent(String.self, forKey: .social)
        firstName = try container.decode(String.self, forKey: .firstName)
        phone = try container.decodeIfPresent(String.self, forKey: .phone) ?? "+1 123456789"
        let addressContainer = try container.nestedContainer(keyedBy: NestedKeys.self, forKey: .address)
        zipCode = try addressContainer.decode(Int.self, forKey: .zip)
    }
}
```

Then

```Swift
let json = """
{
    identifier: "1",
    "social": 987654321,
    "first_name": John,
    "address": {
        "zipCode": 94040,
    }
}
""".data(using: .utf8)!

let result = try JSONDecoder().decode(User.self, from: json)

// or using the provided syntactic sugar

let user = try User.decode(from: json)
```

#### CodableDate

This wrapper allows decoding dates on per-property strategy basis. By default, `CodableDate` uses the `iso8601` strategy. The built-in strategies are: 
`iso8601`, `iso8601WithMillisecondPrecision`, `rfc2822`, `rfc3339`, and `timestamp`. There is also the option of using a custom format by providing a valid string format to the option `.format()`.

```Swift
struct Dates: Kodable {
    @CodableDate var iso8601: Date
    @CodableDate(.format("y-MM-dd"), .key("simple_date")) var simpleDate: Date
    @CodableDate(.rfc2822, .key("rfc2822")) var rfc2822Date: Date
    @CodableDate(.rfc3339, .key("rfc3339")) var rfc3339Date: Date
    @CodableDate(.timestamp, .key("timestamp")) var timestamp: Date
}

let json = """
{
    "iso8601": "1996-12-19T16:39:57-08:00",
    "simple_date": "2001-01-01",
    "rfc2822": "Thu, 19 Dec 1996 16:39:57 GMT",
    "rfc3339": "1996-12-19T16:39:57-08:00",
    "timestamp": 978307200.0,
}
""".data(using: .utf8)!

let dates = Dates.decode(from: json)
print(dates.iso8601.description) // Prints "1996-12-20 00:39:57 +0000"
print(dates.simpleDate.description) // Prints "2001-01-01 00:00:00 +0000"
print(dates.rfc2822Date.description) // Prints "1996-12-19 16:39:57 +0000"
print(dates.rfc3339Date.description) // Prints "1996-12-20 00:39:57 +0000"
print(dates.timestamp.description) // Prints "2001-01-01 00:00:00 +0000"
````

Note that there's no built-in support for ISO8601 dates with precision greater than millisecond (e.g. microsecond or nanosecond), because Apple doesn't officially supports such precision natively, yet. Should you feel the necessity to have those, or any other custom date formatter, you can implement your own `DateConvertible` and use `.custom(dateConvertible)` DateCodingStrategy. If you think your use case should make its way into the official library, PRs are always welcome!

## Advanced Usage


### Lossy Type Decoding

For the types `Array`,  `Bool`, and  `String`, some lossy decoding was introduced. More types can be added later on, but for now these sufficed my personal usage. To disable this behavior for a specific property, in case you want decoding to fail when the type is not correct, just provide the  `enforceTypeDecoding` option to the  `Coding` property wrapper. 

#### Array

The lossy decoding on `Array` is done by trying to decode each element from a `Array.Element` type in a non-lossy way (even if they are `Bool` or `String`) and ignores values that fail decoding. 

```Swift
struct LossyArray: Kodable {
    @Coding("failable_array", .lossy) var array: [String]
}

let json = """
{
    "failable_array": [ "1", 1.5, "2", true, "3", null, 4 ]
}
""".data(using: .utf8)!

let lossy = try LossyArray.decode(from: json)
print(lossy.array) // Prints [ "1", "2", "3" ]
```

#### Bool

Tries to decode a `Bool` from `Int` or `String` if `Bool` fails

```Swift
struct Fail: Kodable {
    @Coding("string_bool", .enforceTypeDecoding) var notBool: Bool
}

struct Success: Kodable {
    @Coding("string_bool") var stringBool: Bool
    @Coding("int_bool") var intBool: Bool
}

let json = """
{
    "string_bool": "false",
    "int_bool": 1,
}
""".data(using: .utf8)!

let success = try Success.decode(from: json)
print(success.stringBool) // prints false
print(success.intBool) // prints true

let fail = try Fail.decode(from: json) // Throws KodableError.invalidValueForPropertyWithKey("string_bool")
```

#### String

Tries to decode a `String` from `Double` or `Int` if `String` fails

```Swift
struct Amounts: Kodable {
    @Coding("double") var double: String
    @Coding("int") var integer: String
    @Coding var string: String
}

let json = """
{
    "double": 629.9,
    "int": 1563,
    "string": "999.9"
}
""".data(using: .utf8)!

let amounts = try Amounts.decode(from: json)
print(amounts.double) // prints "629.9"
print(amounts.integer) // prints "1563"
print(amounts.string) // prints "999.9"
```


### Overriding Values

You can provide a `KodableModifier.custom` modifier with an overriding closure so that you can modify the decoded value before assigning it to the property. 

```Swift
struct Project: Kodable {
    @Coding(.modifier(Project.trimmed)) var title: String
    
    static var trimmed: KodableModifier<String> { 
        KodableModifier { $0.trimmingCharacters(in: .whitespacesAndNewlines) } 
    }
}

let json = #"{ "title": "  A New Project    " }"#.data(using: .utf8)!

let project = try Project.decode(from: json)
print(project.title) // Prints "A New Project"
````

There are a few built in modifiers provided already: 

**String**
- `trimmed` : Applies `trimmingCharacters(in: .whitespacesAndNewlines)` to the value decoded

**String?** 
- `trimmed` : Applies `trimmingCharacters(in: .whitespacesAndNewlines)` to the value decoded
- `trimmedNifIfEmpty` : Applies `trimmingCharacters(in: .whitespacesAndNewlines)` to the value decoded, returns nif if empty

**Sorting**
When the type conforms to the `Comparable` protocol:

- `ascending` or `descending`: Sorts the elements of an array in ascending (or descending) order, using the type's underlying comparison function.

When the type doesn't conform to the `Comparable` protocol, but one of its properties does:

- `ascending(by: KeyPath)` or `descending(by: KeyPath)`: Sorts the elements of an array in ascending (or descending) order, based on the _KeyPath_ property passed.

If there's no conformance to `Comparable` at all, you can resort to basic sorting functionality:
- `sorted(using: Comparator)`: Sorts the elements of an array using a _Comparator_ closure that determines whether the items are in increasing order. In Swifty words: `func < (lhs: Value.Element, rhs: Value.Element) -> Bool`

**Comparable**
- `clamping(to:)` : Clamps the value in a range.
- `range()` : Constrains the value inside a provided range.
- `max()` :  Constrains the value to a maximum value.
- `min()` :  Constrains the value to a minimum value.


### Validating Values

You can provide a `KodableModifier.validation` modifier with a validation closure, where you can verify if the value is valid. 

```Swift
struct Image: Kodable {
    @Coding(.validation({ $0 > 500 })) var width: Int
}

let json = #{ "width": 400 }#.data(using: .utf8)!

let image = try Image.decode(from: json)
// Throws KodableError.validationFailed(property: "width", parsedValue: 400)
````

### Custom Wrapper

`Kodable` was built based on a protocol called `KodableTransform`

```Swift
public protocol KodableTransform {
    associatedtype From: Codable
    associatedtype To
    func transformFromJSON(value: From) throws -> To
    func transformToJSON(value: To) throws -> From
    init()
}
```

If you want to add your own custom behavior, you can create a type that conforms to the `KodableTransform` protocol.:

```Swift
struct URLTransformer: KodableTransform {
    
    enum Error: Swift.Error {
        case failedToCreateURL
    }

    func transformFromJSON(value: String) throws -> URL {
        guard let url = URL(string: value) else { throw Error.failedToCreateURL }
        return url
    }
    
    func transformToJSON(value: URL) throws -> String {
        value.absoluteString
    }
}
```

Then use the `KodableTrasformable` property wrapper, upon which all other wrappers are based: 

```Swift 
typealias CodingURL = KodableTransformable<URLTransformer>
```

And voilà

```Swift
struct Test: Kodable {
    @CodingURL("html_url") var url: URL
}
```

### Encode Null Values

By default optional values won't be encoded so: 

```swift
struct User: Kodable {
    @Coding var firstName: String
    @Coding var lastName: String?
}

let user = User()
user.firstName = "João"
```

When encoded will output: 

```js
{
    "firstName": "João"
}
```

However, if you want to explicitly encode null values, then you can add the `encodeAsNullIfNil` option: 

```swift
struct User: Kodable {
    @Coding var firstName: String
    @Coding(.encodeAsNullIfNil) var lastName: String?
}

let user = User()
user.firstName = "João"
```

Which will then output: 

```js
{
    "firstName": "João",
    "lastName": null
}
```

## Debugging

While developing it might be useful to know what JSON is being received, so that we can be sure that the options chosen lead to correct decoding. There are several ways to do this, however, for simplicity sake, Kodable provides a simple way to print the JSON value received. 

Let's take for example the following JSON and Kodable models:

```swift
{
    "identifier": "1",
    "social": 987654321,
    "first_name": "John",
    "address": {
        "zipCode": 94040,
        "state": "CA"
    },
    "aliases": [ "Jay", "Doe" ]
}

struct Address: Codable {
    let zipCode: Int
    let state: String 
}

struct User: Kodable {
    var identifier: String = ""
    var social: String?
    @Coding("first_name") var firstName: String
    @Coding(default: "+1 123456789") var phone: String
    @Coding var address: Address
}
```

Kodable provides 2 ways to debug the JSON that will be used to decode the `User` model. The first is to check the whole JSON value for the model. To achieve that, conform the model to the `DebugJSON` protocol: 

```swift
struct User: Kodable, DebugJSON {
    /.../
}
```

Whenever an instance of the `User` model is decoded you'll get the following message in the console

```js
Decoded JSON for type User:
{
    "identifier": "1",
    "social": 987654321,
    "first_name": "John",
    "address": {
        "zipCode": 94040,
        "state": "CA"
    },
    "aliases": [ "Jay", "Doe" ]
}
```

However, sometimes the model can be quite extensive and you're only interested in a specific nested model. In that case, there is a second option which is to mark only the property you want with the option `.debugJSON`: 

```Swift
struct User: Kodable {
    var identifier: String = ""
    var social: String?
    @Coding("first_name") var firstName: String
    @Coding(default: "+1 123456789") var phone: String
    @Coding(.debugJSON) var address: Address
}
```

In which case, for every instance of the `User` model that is decoded, you'll get the following message in the console:

```js
Decoded JSON for the address property of type User:
{
    "zipCode": 94040,
    "state": "CA"
}
```

## Contributions

If you feel like something is missing or you want to add any new functionality, please open an issue requesting it and/or submit a pull request with passing tests 🙌

## License

MIT

## Special thanks to

Better Decoding Error Messages - via [@nunogoncalves](https://gist.github.com/nunogoncalves/4852077f4e576872f72b70d9e79942f3)

## Contact

João ([@_JARMourato](https://twitter.com/_JARMourato))

[build status]: https://github.com/JARMourato/Kodable/actions?query=workflow%3ACI
[build status badge]: https://github.com/JARMourato/Kodable/workflows/CI/badge.svg
[codebeat status]: https://codebeat.co/projects/github-com-jarmourato-kodable-main
[codebeat status badge]: https://codebeat.co/badges/5b666fbb-93ee-41ca-92ab-da7d5a8681ce
[codecov status]: https://codecov.io/gh/JARMourato/Kodable
[codecov status badge]: https://codecov.io/gh/JARMourato/Kodable/branch/main/graph/badge.svg?token=XAHCCI1JNM
[platforms badge]: https://img.shields.io/static/v1?label=Platforms&message=iOS%20|%20macOS%20|%20tvOS%20|%20watchOS%20&color=brightgreen
