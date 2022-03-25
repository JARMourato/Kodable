import CwlPreconditionTesting
@testable import Kodable
import XCTest

final class KodableTests: XCTestCase {
    // MARK: - AnyCodingKey Tests

    func testAnyCodingKey() {
        let key1 = AnyCodingKey(intValue: 1)
        let key2 = AnyCodingKey(stringValue: "2")
        let key3 = AnyCodingKey("3")

        XCTAssertEqual(key1?.intValue, 1)
        XCTAssertEqual(key1?.stringValue, "1")
        XCTAssertEqual(key2?.intValue, nil)
        XCTAssertEqual(key2?.stringValue, "2")
        XCTAssertEqual(key3.intValue, nil)
        XCTAssertEqual(key3.stringValue, "3")
    }

    // MARK: - Coding Tests

    func testEnumDecoding() {
        enum Languages: String, Codable {
            case swift, kotlin, java
        }

        struct ExtendedEnum: Kodable {
            @Coding("current_language") var currentLanguage: Languages
            @Coding var languages: [Languages]
        }

        do {
            let value = try ExtendedEnum.decodeJSON(from: KodableTests.json)
            XCTAssertEqual(value.currentLanguage, .swift)
            XCTAssertEqual(value.languages, [.swift, .kotlin, .java])

            let json = try value.encodeJSON()
            let newValue = try ExtendedEnum.decodeJSON(from: json)

            XCTAssertEqual(newValue.currentLanguage, .swift)
            XCTAssertEqual(newValue.languages, [.swift, .kotlin, .java])
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testEncodingNullValuesOutput() throws {
        struct Strings: Kodable {
            @Coding var optionalString: String?
            @Coding(encodeAsNullIfNil: true) var nullOptionalString: String?
        }

        let strings = Strings()
        let data = try strings.encodeJSON()
        let dic = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        XCTAssertFalse(dic!.keys.contains("optionalString"))
        XCTAssertEqual(dic!["nullOptionalString"] as? NSNull, NSNull())
    }

    func testEncodingAndDecodingUsingCoder() {
        struct User: Kodable {
            @Coding("first_name") var firstName: String
            @Coding(default: "Absent optional") var phone: String?
            @Coding(default: "Absent non-optional") var telephone: String
            @Coding("home_address") var address: String?
            @Coding var name: String
        }

        do {
            let user = try User.decodeJSON(from: KodableTests.json)

            XCTAssertEqual(user.firstName, "John")
            XCTAssertEqual(user.phone, "Absent optional")
            XCTAssertEqual(user.telephone, "Absent non-optional")
            XCTAssertEqual(user.address, "Mountain View")
            XCTAssertEqual(user.name, "John Doe")

            let json = try user.encodeJSON()
            let newUser = try User.decodeJSON(from: json)

            XCTAssertEqual(newUser.firstName, "John")
            XCTAssertEqual(newUser.phone, "Absent optional")
            XCTAssertEqual(newUser.telephone, "Absent non-optional")
            XCTAssertEqual(newUser.address, "Mountain View")
            XCTAssertEqual(newUser.name, "John Doe")
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testFailedDecodingUsingCodeAbsentNonOptional() {
        struct User: Kodable {
            @Coding(default: "Absent") var phone: String
        }

        struct FailingUser: Kodable {
            @Coding var phone: String
        }

        do {
            let user = try User.decodeJSON(from: KodableTests.json)
            XCTAssertEqual(user.phone, "Absent")
        } catch {
            XCTFail(error.localizedDescription)
        }

        assert(try FailingUser.decodeJSON(from: KodableTests.json),
               throws: KodableError.failedDecodingType(type: FailingUser.self, underlyingError: .wrappedError(DummyError())))
    }

    func testNestedKeys() {
        struct User: Kodable {
            @Coding var name: String
            @Coding("address.zip") var addressZipCode: Int
            @Coding("address.parts.first") var addressFirstPart: String
        }

        do {
            let object = try User.decodeJSON(from: KodableTests.json)

            XCTAssertEqual(object.name, "John Doe")
            XCTAssertEqual(object.addressZipCode, 90000)
            XCTAssertEqual(object.addressFirstPart, "random address")

            let json = try object.encodeJSON()
            let newObject = try User.decodeJSON(from: json)

            XCTAssertEqual(newObject.name, "John Doe")
            XCTAssertEqual(newObject.addressZipCode, 90000)
            XCTAssertEqual(newObject.addressFirstPart, "random address")
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testFatalErrorAccessingNonOptionalBeforeDecoding() {
        struct Basic: Kodable {
            @Coding var basicID: Int
        }

        // Accessing a non-optional property should crash cause there is no default value
        XCTAssertNotNil(catchBadInstruction { _ = Basic().basicID })
    }

    // MARK: - Test Modifiers

    func testBasicModifiers() {
        struct Basic: Kodable {
            @Coding("id") var basicID: Int
            @Coding("title", .trimmed) var basicTitle: String
            @Coding("title", .trimmed) var optionalTitle: String?
            @Coding("empty", .trimmedNifIfEmpty) var emptyTitle: String?
            @Coding(.max(350)) var width: Int
            @Coding(.min(500)) var height: Int
            @Coding("height", .range(100 ... 500)) var rangeHeight: Int
            @Coding("views_count", .clamping(to: 5000 ... 5400)) var views: Int
            @Coding("images.teaser", .validation { URL(string: $0) != nil }) var teaseImageStringURL: String
            @Coding("comments_count", .overrideValue { $0.constrained(toAtMost: 10) }) var commentsCount: Int
        }

        do {
            let decoded = try Basic.decodeJSON(from: KodableTests.json)

            XCTAssertEqual(decoded.basicID, 2_623_488)
            XCTAssertEqual(decoded.basicTitle, "Create New Project")
            XCTAssertEqual(decoded.optionalTitle, "Create New Project")
            XCTAssertEqual(decoded.emptyTitle, nil)
            XCTAssertEqual(decoded.rangeHeight, 300)
            XCTAssertEqual(decoded.height, 500)
            XCTAssertEqual(decoded.width, 350)
            XCTAssertEqual(decoded.views, 5400)
            XCTAssertEqual(decoded.teaseImageStringURL, "https://d13yacurqjgara.cloudfront.net/users/136707/screenshots/2623488/create_new_project_teaser.gif")
            XCTAssertEqual(decoded.commentsCount, 10)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testValidationFailed() {
        struct Failed: Kodable {
            @Coding(.validation { $0 > 500 }) var width: Int
        }

        let data = KodableTests.json
        assert(try Failed.decodeJSON(from: data),
               throws: KodableError.failedDecodingType(type: Failed.self, underlyingError: .wrappedError(DummyError())))
    }

    func testEnforceType() {
        struct Failed: Kodable {
            @Coding("string_bool", decoding: .enforceType) var notBool: Bool
        }

        struct Success: Kodable {
            @Coding("animated", decoding: .enforceType) var isBool: Bool
        }

        do {
            let success = try Success.decodeJSON(from: KodableTests.json)
            XCTAssertEqual(success.isBool, true)
        } catch {
            XCTFail(error.localizedDescription)
        }

        let data = KodableTests.json

        assert(try Failed.decodeJSON(from: data),
               throws: KodableError.failedDecodingType(type: Failed.self, underlyingError: .wrappedError(DummyError())))
    }

    func testMissingProperty() {
        struct Failed: Kodable {
            @Coding var size: Int
        }

        let data = KodableTests.json

        assert(try Failed.decodeJSON(from: data),
               throws: KodableError.failedDecodingType(type: Failed.self, underlyingError: .wrappedError(DummyError())))
    }

    func testInvalidDataForProperty() {
        struct NonOptionalDateTransformer: KodableTransform {
            internal var strategy: DateCodingStrategy = .iso8601

            public func transformFromJSON(value: String) throws -> Date {
                let dateValue = strategy.date(from: value)
                guard let date = dateValue else { throw KodableError.failedToParseDate(source: value) }
                return date
            }

            public func transformToJSON(value: Date) throws -> String {
                strategy.string(from: value)
            }

            public init() {}
        }

        struct Failed: Kodable {
            @Coding var animated: Int
        }

        let data = KodableTests.json

        assert(try Failed.decodeJSON(from: data),
               throws: KodableError.failedDecodingType(type: Failed.self, underlyingError: .wrappedError(DummyError())))
    }

    func testInheritance() {
        class Person: Kodable {
            var name: String?
            required init() {}
        }

        class Contact: Person {
            var social: String?
            var phoneNumber: String?
            required init() {}
        }

        do {
            let object = try Contact.decodeJSON(from: KodableTests.json)

            XCTAssertEqual(object.name, "John Doe")
            XCTAssertEqual(object.social, "123456789987654321")
            XCTAssertEqual(object.phoneNumber, nil)

            let json = try object.encodeJSON()
            let newObject = try Contact.decodeJSON(from: json)

            XCTAssertEqual(newObject.name, "John Doe")
            XCTAssertEqual(newObject.social, "123456789987654321")
            XCTAssertEqual(newObject.phoneNumber, nil)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testComposition() {
        struct Dog: Kodable {
            var name: String?
        }

        struct Owner: Kodable {
            var name: String?
            var favorites: [Dog] = []
            @Coding(default: []) var dogs: [Dog]
            @Coding("sick_dogs") var sick: [Dog]
        }

        do {
            let object = try JSONDecoder().decode(Owner.self, from: KodableTests.json)

            XCTAssertEqual(object.name, "John Doe")
            XCTAssertTrue(object.dogs.isEmpty)
            XCTAssertEqual(object.sick.first?.name, "pete")
            XCTAssertEqual(object.sick.count, 2)
            XCTAssertEqual(object.favorites.first?.name, "jen")
            XCTAssertEqual(object.favorites.count, 2)

            let json = try JSONEncoder().encode(object)
            let newObject = try JSONDecoder().decode(Owner.self, from: json)

            XCTAssertEqual(newObject.name, "John Doe")
            XCTAssertTrue(newObject.dogs.isEmpty)
            XCTAssertEqual(newObject.sick.first?.name, "pete")
            XCTAssertEqual(newObject.sick.count, 2)
            XCTAssertEqual(newObject.favorites.first?.name, "jen")
            XCTAssertEqual(newObject.favorites.count, 2)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    // MARK: - Lossless Tests

    func testLosslessBoolDecoding() {
        struct Bools: Kodable {
            @Coding("animated") var regularBool: Bool
            @Coding("optional_bool") var optionalBool: Bool?
            @Coding("string_bool", decoding: .lossless) var boolFromString: Bool
            @Coding("int_bool", decoding: .lossless) var boolFromInt: Bool
        }

        do {
            let value = try Bools.decodeJSON(from: KodableTests.json)

            XCTAssertEqual(value.regularBool, true)
            XCTAssertEqual(value.optionalBool, nil)
            XCTAssertEqual(value.boolFromString, false)
            XCTAssertEqual(value.boolFromInt, true)

            let json = try value.encodeJSON()
            let newValue = try Bools.decodeJSON(from: json)

            XCTAssertEqual(newValue.regularBool, true)
            XCTAssertEqual(newValue.optionalBool, nil)
            XCTAssertEqual(newValue.boolFromString, false)
            XCTAssertEqual(newValue.boolFromInt, true)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testLosslessStringDecoding() {
        struct Strings: Kodable {
            @Coding("first_name") var regularString: String
            @Coding("home_address") var optionalString: String?
            @Coding("width", decoding: .lossless) var stringFromInt: String
            @Coding("amount", decoding: .lossless) var stringFromDouble: String
        }

        struct FailingString: Kodable {
            @Coding("languages", decoding: .lossless) var string: String
        }

        struct MissingString: Kodable {
            @Coding("missing_languages", decoding: .lossless) var string: String
        }

        do {
            let value = try Strings.decodeJSON(from: KodableTests.json)

            XCTAssertEqual(value.regularString, "John")
            XCTAssertEqual(value.optionalString, "Mountain View")
            XCTAssertEqual(value.stringFromInt, "400")
            XCTAssertEqual(value.stringFromDouble, "629.9")

            let json = try value.encodeJSON()
            let newValue = try Strings.decodeJSON(from: json)

            XCTAssertEqual(newValue.regularString, "John")
            XCTAssertEqual(newValue.optionalString, "Mountain View")
            XCTAssertEqual(newValue.stringFromInt, "400")
            XCTAssertEqual(newValue.stringFromDouble, "629.9")
        } catch {
            XCTFail(error.localizedDescription)
        }

        assert(try MissingString.decodeJSON(from: KodableTests.json),
               throws: KodableError.failedDecodingType(type: MissingString.self, underlyingError: .wrappedError(DummyError())))
        assert(try FailingString.decodeJSON(from: KodableTests.json),
               throws: KodableError.failedDecodingType(type: FailingString.self, underlyingError: .wrappedError(DummyError())))
    }

    func testOptionalLosslessDecodableConformance() {
        let nonOptional: String? = "Non Optional"
        let optional: String? = .none
        XCTAssertEqual(nonOptional.description, "Non Optional")
        XCTAssertEqual(optional.description, "Empty Optional<\(String(describing: String.self))>")
    }

    // MARK: - Collection Tests

    func testDictionary() {
        struct Holder: Kodable {
            @Coding var properties: [String: String]
            var metadata: [String: String] = [:]
        }

        let json = """
        {
            "properties": {
                "abc": "123",
                "def": "456"
            },
            "metadata": {
                "ghi": "789",
                "jkl": "10"
            }
        }
        """

        guard let data = json.data(using: .utf8) else { return XCTFail() }

        do {
            let holder = try JSONDecoder().decode(Holder.self, from: data)

            XCTAssertEqual(holder.properties.count, 2)
            XCTAssertEqual(holder.properties["abc"], "123")
            XCTAssertEqual(holder.properties["def"], "456")
            XCTAssertEqual(holder.metadata.count, 2)
            XCTAssertEqual(holder.metadata["ghi"], "789")
            XCTAssertEqual(holder.metadata["jkl"], "10")

            let json = try JSONEncoder().encode(holder)
            let newHolder = try JSONDecoder().decode(Holder.self, from: json)

            XCTAssertEqual(newHolder.properties.count, 2)
            XCTAssertEqual(newHolder.properties["abc"], "123")
            XCTAssertEqual(newHolder.properties["def"], "456")
            XCTAssertEqual(newHolder.metadata.count, 2)
            XCTAssertEqual(newHolder.metadata["ghi"], "789")
            XCTAssertEqual(newHolder.metadata["jkl"], "10")
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testArrays() {
        struct Arrays: Kodable {
            @Coding var one: [String]
            var two: [Int]?
            @Coding(default: []) var three: [Int]
        }

        struct LosslessArray: Kodable {
            @Coding("failable_array", decoding: .lossless) var array: [String]?
        }

        struct LossyStruct: Kodable {
            @Coding("name", decoding: .lossless) var name: String
        }

        struct LossyArray: Kodable {
            @Coding("failable_lossy_array", decoding: .lossy) var array: [LossyStruct]
        }

        struct EnforcedTypeArray: Kodable {
            @Coding("failable_array", decoding: .enforceType)
            var array: [String]
        }

        struct InvalidLosslessArray: Kodable {
            @Coding("failable_lossy_array", decoding: .lossless) var array: [LossyStruct]
        }

        struct MissingArray: Kodable {
            @Coding("missing_array") var array: [String]
        }

        do {
            let object = try JSONDecoder().decode(Arrays.self, from: KodableTests.json)

            XCTAssertEqual(object.one, ["A", "B", "C"])
            XCTAssertEqual(object.two, [1, 2, 3, 4])
            XCTAssertEqual(object.three, [])

            let json = try JSONEncoder().encode(object)
            let newObject = try JSONDecoder().decode(Arrays.self, from: json)

            XCTAssertEqual(newObject.one, ["A", "B", "C"])
            XCTAssertEqual(newObject.two, [1, 2, 3, 4])
            XCTAssertEqual(newObject.three, [])

            let lossless = try LosslessArray.decodeJSON(from: KodableTests.json)
            XCTAssertEqual(lossless.array, ["1", "1.5", "2", "true", "3", "4"])

            let lossy = try LossyArray.decodeJSON(from: KodableTests.json)
            XCTAssertEqual(lossy.array[0].name, "1")
            XCTAssertEqual(lossy.array[1].name, "john")
        } catch {
            XCTFail(error.localizedDescription)
        }

        assert(try EnforcedTypeArray.decodeJSON(from: KodableTests.json),
               throws: KodableError.failedDecodingType(type: EnforcedTypeArray.self, underlyingError: .wrappedError(DummyError())))

        assert(try InvalidLosslessArray.decodeJSON(from: KodableTests.json),
               throws: KodableError.failedDecodingType(type: InvalidLosslessArray.self, underlyingError: .wrappedError(DummyError())))
        assert(try MissingArray.decodeJSON(from: KodableTests.json),
               throws: KodableError.failedDecodingType(type: MissingArray.self, underlyingError: .wrappedError(DummyError())))
    }

    // MARK: - Mix And Match With Codable Tests

    func testEncodingAndDecodingUsingCodeMixAndMatchCodable() {
        struct User: Kodable {
            @Coding("first_name") var firstName: String
            @Coding(default: "Absent optional") var phone: String?
            @Coding(default: "Absent non-optional") var telephone: String
            @Coding("home_address") var address: String?
            @Coding("amount", decoding: .lossless) var amountString: String?
            @Coding("animated") var hasAnimation: Bool
            @Coding("animated") var optionalAnimation: Bool?
            @Coding var name: String
            var social: String?
            var identifier: String = ""
            var amount: Double = 0
            var width: Int = 0
            var animated: Bool = false
            var nonExistent: Float?
        }

        do {
            let user = try User.decodeJSON(from: KodableTests.json)

            XCTAssertEqual(user.firstName, "John")
            XCTAssertEqual(user.phone, "Absent optional")
            XCTAssertEqual(user.telephone, "Absent non-optional")
            XCTAssertEqual(user.address, "Mountain View")
            XCTAssertEqual(user.amountString, "629.9")
            XCTAssertEqual(user.hasAnimation, true)
            XCTAssertEqual(user.optionalAnimation, true)
            XCTAssertEqual(user.name, "John Doe")
            XCTAssertEqual(user.social, "123456789987654321")
            XCTAssertEqual(user.identifier, "1234")
            XCTAssertEqual(user.amount, Double(629.9))
            XCTAssertEqual(user.width, 400)
            XCTAssertEqual(user.animated, true)
            XCTAssertEqual(user.nonExistent, nil)

            let json = try user.encodeJSON()
            let newUser = try User.decodeJSON(from: json)

            XCTAssertEqual(newUser.firstName, "John")
            XCTAssertEqual(newUser.phone, "Absent optional")
            XCTAssertEqual(newUser.telephone, "Absent non-optional")
            XCTAssertEqual(newUser.address, "Mountain View")
            XCTAssertEqual(newUser.amountString, "629.9")
            XCTAssertEqual(newUser.hasAnimation, true)
            XCTAssertEqual(newUser.optionalAnimation, true)
            XCTAssertEqual(newUser.name, "John Doe")
            XCTAssertEqual(newUser.social, "123456789987654321")
            XCTAssertEqual(newUser.identifier, "1234")
            XCTAssertEqual(newUser.amount, Double(629.9))
            XCTAssertEqual(newUser.width, 400)
            XCTAssertEqual(newUser.animated, true)
            XCTAssertEqual(newUser.nonExistent, nil)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    func testCompositionWithCodable() {
        struct User: Kodable {
            @Coding var name: String
            @Coding var address: Address
        }

        struct Address: Codable {
            var zip: Int
        }

        do {
            let object = try JSONDecoder().decode(User.self, from: KodableTests.json)

            XCTAssertEqual(object.name, "John Doe")
            XCTAssertEqual(object.address.zip, 90000)

            let json = try JSONEncoder().encode(object)
            let newObject = try JSONDecoder().decode(User.self, from: json)

            XCTAssertEqual(newObject.name, "John Doe")
            XCTAssertEqual(newObject.address.zip, 90000)
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    // MARK: - Equatable

    func testCodableConformsToEquatable() {
        struct User: Kodable, Equatable {
            @Coding var name: String

            static func with(name: String) -> User {
                let user = User()
                user.name = name
                return user
            }
        }

        let a = User.with(name: "João")
        let b = User.with(name: "Roger")
        let c = a

        XCTAssertNotEqual(a.name, b.name)
        XCTAssertNotEqual(a, b)
        XCTAssertEqual(a.name, c.name)
        XCTAssertEqual(a, c)
    }

    // MARK: - CodableDate

    func testDateTransformerFailedToParseError() {
        let transformer = DateTransformer<Date>()
        let optionalTransformer = DateTransformer<Date?>()

        assert(try transformer.transformFromJSON(value: nil), throws: KodableError.failedToParseDate(source: "nil"))
        XCTAssertEqual(try optionalTransformer.transformFromJSON(value: nil), nil)
    }

    func testCodableDate() throws {
        struct MyDateParser: DateConvertible {
            func date(from _: String) -> Date? {
                Date(timeIntervalSince1970: 123)
            }

            func string(from _: Date) -> String {
                "Kodable"
            }
        }

        struct Dates: Kodable {
            @CodableDate(decoding: .enforceType) var iso8601: Date
            @CodableDate("iso8601") var isoDate: Date?
            @CodableDate(.iso8601WithMillisecondPrecision, "iso8601_millisecond_date") var isoNanosecondDate: Date?
            @CodableDate(.format("y-MM-dd"), "simple_date") var simpleDate: Date
            @CodableDate(.rfc2822, "rfc2822") var rfc2822Date: Date
            @CodableDate(.rfc3339, "rfc3339") var rfc3339Date: Date
            @CodableDate(.timestamp, "timestamp", decoding: .lossless) var nonOptionalTimestamp: Date
            @CodableDate(.timestamp, "timestamp", decoding: .lossless) var timestamp: Date?
            @CodableDate(.custom(MyDateParser()), "custom_date") var customDate: Date?
            @CodableDate var optionalDate: Date?

            @CodableDate(.timestamp, "timestamp_non_existent", default: KodableTests.testDate)
            var defaultTimestamp: Date

            var ignoredDate: Date? = KodableTests.testDate
        }

        struct CodableDates: Codable {
            @CodableDate var iso8601: Date
            // Since we only use `Codable` the passed modifiers should be ignored
            @CodableDate(.rfc2822, "rfc3339") var duplicateIso: Date
        }

        // Regular codable
        let codableDecoded = try CodableDates.decodeJSON(from: KodableTests.json)
        XCTAssertEqual(codableDecoded.iso8601.description, "1996-12-20 00:39:57 +0000")
        XCTAssertEqual(codableDecoded.duplicateIso.description, "1996-12-20 00:39:57 +0000")

        let encodableJson = try codableDecoded.encodeJSON()
        let newCodableObject = try CodableDates.decodeJSON(from: encodableJson)
        XCTAssertEqual(newCodableObject.iso8601.description, "1996-12-20 00:39:57 +0000")
        XCTAssertEqual(newCodableObject.duplicateIso.description, "1996-12-20 00:39:57 +0000")

        // ExtendedCodable
        let decoded = try Dates.decodeJSON(from: KodableTests.json)
        XCTAssertEqual(decoded.iso8601.description, "1996-12-20 00:39:57 +0000")
        XCTAssertEqual(decoded.isoDate?.description, "1996-12-20 00:39:57 +0000")
        XCTAssertEqual(decoded.isoNanosecondDate?.description, "2021-08-30 18:35:19 +0000")
        XCTAssertEqual(decoded.simpleDate.description, "2001-01-01 00:00:00 +0000")
        XCTAssertEqual(decoded.rfc2822Date.description, "1996-12-19 16:39:57 +0000")
        XCTAssertEqual(decoded.rfc3339Date.description, "1996-12-20 00:39:57 +0000")
        XCTAssertEqual(decoded.nonOptionalTimestamp.description, "2001-01-01 00:00:00 +0000")
        XCTAssertEqual(decoded.timestamp?.description, "2001-01-01 00:00:00 +0000")
        XCTAssertEqual(decoded.customDate?.description, "1970-01-01 00:02:03 +0000")
        XCTAssertEqual(decoded.defaultTimestamp.description, KodableTests.testDate.description)
        XCTAssertEqual(decoded.optionalDate, nil)
        XCTAssertEqual(decoded.ignoredDate, nil)

        let json = try decoded.encodeJSON()
        let newObject = try Dates.decodeJSON(from: json)

        XCTAssertEqual(newObject.isoDate?.description, "1996-12-20 00:39:57 +0000")
        XCTAssertEqual(newObject.isoNanosecondDate?.description, "2021-08-30 18:35:19 +0000")
        XCTAssertEqual(newObject.simpleDate.description, "2001-01-01 00:00:00 +0000")
        XCTAssertEqual(newObject.rfc2822Date.description, "1996-12-19 16:39:57 +0000")
        XCTAssertEqual(newObject.rfc3339Date.description, "1996-12-20 00:39:57 +0000")
        XCTAssertEqual(newObject.nonOptionalTimestamp.description, "2001-01-01 00:00:00 +0000")
        XCTAssertEqual(newObject.timestamp?.description, "2001-01-01 00:00:00 +0000")
        XCTAssertEqual(newObject.customDate?.description, "1970-01-01 00:02:03 +0000")
        XCTAssertEqual(newObject.defaultTimestamp.description, KodableTests.testDate.description)
        XCTAssertEqual(newObject.optionalDate, nil)
        XCTAssertEqual(newObject.ignoredDate, nil)
    }

    func testISO8601DateCodingStrategy() {
        // Our tests don't cover microsecond and nanosecond precision dates because our date formatters don't actually support them yet.
        let iso8601 = "2021-08-30T18:35:19Z"
        let iso8601WithMillisecondPrecision = "2021-08-30T18:35:19.999Z"

        func assert(_ dateString: String, against formatter: DateCodingStrategy) {
            if let date = formatter.date(from: dateString) {
                XCTAssertEqual(formatter.string(from: date), dateString)
            } else {
                XCTFail("Failed to initialize date from \(dateString) using \(formatter)")
            }
        }
        assert(iso8601, against: .iso8601)
        assert(iso8601WithMillisecondPrecision, against: .iso8601WithMillisecondPrecision)
    }

    func testFailedCodableDate() {
        struct Dates: Kodable {
            @CodableDate("social") var isoDate: Date
        }
        assert(try Dates.decodeJSON(from: KodableTests.json),
               throws: KodableError.failedDecodingType(type: Dates.self, underlyingError: .wrappedError(DummyError())))
    }

    // MARK: - Equatable

    func testCodableDateConformsToEquatable() throws {
        struct RFCDate: Kodable, Equatable {
            @CodableDate(.rfc2822, "rfc2822") var date: Date

            static func fromJSON() throws -> RFCDate {
                try RFCDate.decodeJSON(from: KodableTests.json)
            }

            static func now() -> RFCDate {
                let now = RFCDate()
                now.date = Date()
                return now
            }
        }

        let a = try RFCDate.fromJSON()
        let b = RFCDate.now()
        let c = a

        XCTAssertNotEqual(a.date, b.date)
        XCTAssertNotEqual(a, b)
        XCTAssertEqual(a.date, c.date)
        XCTAssertEqual(a, c)
    }

    // MARK: - Flattened Tests

    // https://gist.github.com/rogerluan/ee04febd80371f88f9435e98032b3042
    func testFlattened() {
        XCTAssert(isEqual(type: Int?.self, a: Optional(1).flattened(), b: Optional(1)))
        XCTAssert(isEqual(type: Int?.self, a: Int?.none.flattened(), b: nil))
        XCTAssert(isEqual(type: Int?.self, a: Int?.some(1).flattened(), b: Optional(1)))
        XCTAssert(isEqual(type: Int?.self, a: Int??.none?.flattened(), b: nil))
        XCTAssert(isEqual(type: Int?.self, a: Int??.some(Int?.none).flattened(), b: nil))
        XCTAssert(isEqual(type: Int?.self, a: Int??.some(Int?.some(1)).flattened(), b: 1))
        XCTAssert(isEqual(type: Int?.self, a: Int??.some(1).flattened(), b: Optional(1)))
        XCTAssert(isEqual(type: Int?.self, a: Int???.some(1).flattened(), b: Optional(1)))
        XCTAssert(isEqual(type: Int?.self, a: Int????.some(1).flattened(), b: Optional(1)))
        XCTAssert(isEqual(type: Int?.self, a: Int?????.some(1).flattened(), b: Optional(1)))
        XCTAssert(isEqual(type: Int?.self, a: Int??????.some(1).flattened(), b: Optional(1)))
        XCTAssert(isEqual(type: Int?.self, a: Int???????.some(1).flattened(), b: Optional(1)))
        XCTAssert(isEqual(type: Int?.self, a: Int???.none.flattened(), b: nil))
        XCTAssert(isEqual(type: Int?.self, a: Int????.none.flattened(), b: nil))
        XCTAssert(isEqual(type: Int?.self, a: Int?????.none.flattened(), b: nil))
        XCTAssert(isEqual(type: Int?.self, a: Int??????.none.flattened(), b: nil))
        XCTAssert(isEqual(type: Int?.self, a: Int???????.none.flattened(), b: nil))
        let _20levelsNested: Int???????????????????? = 20
        XCTAssert(isEqual(type: Int?.self, a: _20levelsNested.flattened(), b: Optional(20)))
    }

    // MARK: - OptionalProtocol Tests

    func testOptionalProtocolIsNil() {
        let nonNilValue: String? = ""
        let doubleNonNilValue: String?? = ""
        let nilValue: String? = nil
        let doubleNilValue: String?? = nil
        let optionalEnum: String?? = .some(nil)

        XCTAssertFalse(nonNilValue.isNil)
        XCTAssertFalse(doubleNonNilValue.isNil)
        XCTAssertTrue(nilValue.isNil)
        XCTAssertTrue(doubleNilValue.isNil)
        XCTAssertTrue(optionalEnum.isNil)
    }

    // MARK: - Error Tests

    func testInternalErrorDataNotFoundReturnsExpectedDescription() {
        XCTAssertEqual(DataNotFound().description, "Missing key (or null value) for property marked as required.")
    }

    func testFailableExpressionAndFallBackError() throws {
        struct FirstError: Error {}
        struct SecondError: Error {}

        typealias Expression = () throws -> Int
        let successExpresion: Expression = { 1 }
        let firstError: Expression = { throw FirstError() }
        let secondError: Expression = { throw SecondError() }

        let success = try failableExpression(successExpresion(), withFallback: successExpresion())
        XCTAssertEqual(success, 1)
        let firstErrorButResult = try failableExpression(firstError(), withFallback: successExpresion())
        XCTAssertEqual(firstErrorButResult, 1)
        assert(try failableExpression(firstError(), withFallback: secondError()), throws: FailableExpressionWithFallbackError(main: FirstError(), fallback: SecondError()))
    }

    func testKodableErrorNode() throws {
        XCTAssertEqual(KodableError.Node(type: String.self, propertyName: "", key: "").description, "* failing type \(String.self)")
        XCTAssertEqual(KodableError.Node(type: String.self, propertyName: "property", key: "property").description, "* failing property: \"\("property")\" of type \(String.self)")
        XCTAssertEqual(KodableError.Node(type: String.self, propertyName: "dateCreated", key: "created_at").description, "* failing property: \"\("dateCreated")\"(key: \"\("created_at")\") of type \(String.self)")
    }

    func testBetterDecodingError() {
        let context: DecodingError.Context = .init(codingPath: [], debugDescription: "", underlyingError: nil)
        // Any Error
        XCTAssertEqual(BetterDecodingError(with: DummyError()).description, DummyError().localizedDescription)
        // Data Corrupted
        let dataCorrupted = DecodingError.dataCorrupted(context)
        XCTAssertEqual(BetterDecodingError(with: dataCorrupted).description, "Data corrupted. \(context.debugDescription) ")
        // Key Not Found
        let keyNotFound = DecodingError.keyNotFound(AnyCodingKey(stringValue: "key")!, context)
        XCTAssertEqual(BetterDecodingError(with: keyNotFound).description, "Key not found. Expected -> \("key") <- at: \(context.prettyPath())")
        // Type Mismatch
        let typeMismatch = DecodingError.typeMismatch(String.self, context)
        XCTAssertEqual(BetterDecodingError(with: typeMismatch).description, "Type mismatch. \(context.debugDescription), at: \(context.prettyPath())")
        // Value Not Found
        let valueNotFound = DecodingError.valueNotFound(String.self, context)
        XCTAssertEqual(BetterDecodingError(with: valueNotFound).description, "Value not found. -> \(context.prettyPath()) <- \(context.debugDescription)")
    }

    func testKodableErrorIsEquatable() {
        XCTAssertNotEqual(KodableError.wrappedError(DummyError()), KodableError.wrappedError(DummyError()))
        XCTAssertEqual(KodableError.failedToParseDate(source: "29-03-2020"), KodableError.failedToParseDate(source: "29-03-2020"))
        XCTAssertEqual(KodableError.validationFailed(type: String.self, property: "same", parsedValue: 1), KodableError.validationFailed(type: String.self, property: "same", parsedValue: 2))
        let sameError = KodableError.failedToParseDate(source: "corrupted_date")
        XCTAssertEqual(KodableError.failedDecodingProperty(property: "date", key: "createdAt", type: Date.self, underlyingError: sameError), KodableError.failedDecodingProperty(property: "date", key: "createdAt", type: Date.self, underlyingError: sameError))
        XCTAssertEqual(KodableError.failedDecodingType(type: Int.self, underlyingError: sameError), KodableError.failedDecodingType(type: Int.self, underlyingError: sameError))
        XCTAssertNotEqual(KodableError.failedDecodingType(type: Int.self, underlyingError: sameError), KodableError.wrappedError(DummyError()))
    }

    func testKodableErrorDescription() {
        XCTAssertEqual(KodableError.wrappedError(DummyError()).errorDescription, "Cause: \(BetterDecodingError(with: DummyError()).description)")
        XCTAssertEqual(KodableError.failedToParseDate(source: "30-01-2022").errorDescription, "Could not parse Date from this value: \("30-01-2022")")
        XCTAssertEqual(KodableError.validationFailed(type: String.self, property: "property", parsedValue: 1).errorDescription, "Could not decode type \(String.self). Validation for the property \("property") failed. The parsed value was \(1)")
        XCTAssertEqual(KodableError.failedDecodingProperty(property: "property", key: "key", type: String.self, underlyingError: .wrappedError(DummyError())).errorDescription, "Could not decode type \(String.self). Failed to decode property \("property") for key \("key")")
        XCTAssertEqual(KodableError.failedDecodingType(type: String.self, underlyingError: .wrappedError(DummyError())).errorDescription, "Could not decode an instance of \(String.self):\n")
    }

    func testKodableInternalNode() {
        let validationFailed = KodableError.validationFailed(type: Date.self, property: "property", parsedValue: 1)
        let failedToParseDate = KodableError.failedToParseDate(source: "29-12-2022")
        let failedDecodingType = KodableError.failedDecodingType(type: Date.self, underlyingError: failedToParseDate)
        // Test Failed Decoding Type
        XCTAssertEqual(failedDecodingType.nextIteration?.0, failedToParseDate.nextIteration?.0)
        XCTAssertEqual(failedDecodingType.nextIteration?.1, failedToParseDate.nextIteration?.1)
        // Test Failed Decoding Property
        let failedDecodingProperty = KodableError.failedDecodingProperty(property: "property", key: "key", type: Date.self, underlyingError: failedToParseDate)
        XCTAssertEqual(failedDecodingProperty.nextIteration?.0, KodableError.Node(type: Date.self, propertyName: "property", key: "key"))
        XCTAssertEqual(failedDecodingProperty.nextIteration?.1, failedToParseDate)
        // Test Failed To Parse Date
        XCTAssertNil(failedToParseDate.nextIteration)
        // Test Validation Failed
        XCTAssertNil(validationFailed.nextIteration)

        // Test Wrapped Error
        // Nil for non Kodable Errors
        XCTAssertNil(KodableError.wrappedError(DummyError()).nextIteration)
        // Passthrough for all Kodable Errors but failedDecodingType
        XCTAssertEqual(KodableError.wrappedError(failedToParseDate).nextIteration?.0, failedToParseDate.nextIteration?.0)
        XCTAssertEqual(KodableError.wrappedError(failedToParseDate).nextIteration?.1, failedToParseDate.nextIteration?.1)
        // Special Handling for failedDecodingType
        XCTAssertEqual(KodableError.wrappedError(failedDecodingType).nextIteration?.0, KodableError.Node(type: Date.self, propertyName: "", key: ""))
        XCTAssertEqual(KodableError.wrappedError(failedDecodingType).nextIteration?.1, failedToParseDate)
    }

    // MARK: - Utilities

    /// Utility to compare `Any?` elements.
    private func isEqual<T: Equatable>(type _: T.Type, a: Any?, b: Any?) -> Bool {
        guard let a = a as? T, let b = b as? T else { return false }
        return a == b
    }

    // MARK: - Test Data

    struct DummyError: Error {}

    static let testDate = Date()

    static let dummyDic: [String: Any] = [
        "first_name": "John",
        "home_address": "Mountain View",
        "social": "123456789987654321",
        "identifier": "1234",
        "name": "John Doe",
        "address": [
            "zip": 90000,
            "parts": ["first": "random address"],
        ],
        "iso8601": "1996-12-19T16:39:57-08:00",
        "iso8601_millisecond_date": "2021-08-30T18:35:19.001Z",
        "duplicateIso": "1996-12-19T16:39:57-08:00",
        "simple_date": "2001-01-01",
        "rfc2822": "Thu, 19 Dec 1996 16:39:57 GMT",
        "rfc3339": "1996-12-19T16:39:57-08:00",
        "timestamp": 978_307_200.0,
        "custom_date": "lorem ipsum",
        "id": 2_623_488,
        "title": "     Create New Project       ",
        "empty": "       ",
        "description": "<p>Soon when you create a new project, you’ll be able to see all your options at once, on a single screen. Look closely and you might spot more upcoming UI changes here too!</p>\n\n<p><strong>Press L</strong> to show some love</p>\n\n<p>Follow the <a href=\"https://dribbble.com/InVisionApp\" rel=\"nofollow noreferrer\">InVision Team</a></p>\n\n<p>Not collaborating with InVision yet? <a href=\"http://www.invisionapp.com/\" rel=\"nofollow noreferrer\">Sign Up - Free Forever!</a></p>",
        "width": 400,
        "height": 300,
        "images": [
            "hidpi": "https://d13yacurqjgara.cloudfront.net/users/136707/screenshots/2623488/create_new_project.gif",
            "normal": "https://d13yacurqjgara.cloudfront.net/users/136707/screenshots/2623488/create_new_project_1x.gif",
            "teaser": "https://d13yacurqjgara.cloudfront.net/users/136707/screenshots/2623488/create_new_project_teaser.gif",
        ],
        "views_count": 5454,
        "likes_count": 511,
        "comments_count": 19,
        "attachments_count": 1,
        "rebounds_count": 0,
        "buckets_count": 42,
        "created_at": "2016-03-31T10:56:34Z",
        "updated_at": "2016-03-31T11:02:27Z",
        "html_url": "https://dribbble.com/shots/2623488-Create-New-Project",
        "animated": true,
        "sick_dogs": [
            ["name": "pete"], ["name": "brad"],
        ],
        "favorites": [
            ["name": "jen"], ["name": "joey"],
        ],
        "one": ["A", "B", "C"],
        "two": [1, 2, 3, 4],
        "three": "Invalid Value",
        "failable_array": ["1", 1.5, "2", true, "3", nil, 4],
        "failable_lossy_array": [["name": 1], ["dragonite": "this key will fail to be parsed"], ["name": "john"]],
        "age": "18",
        "cm_height": "170",
        "children_count": "invalid",
        "amount": 629.9,
        "current_language": "swift",
        "languages": ["swift", "kotlin", "java"],
        "string_bool": "false",
        "int_bool": 1,
    ]

    static var json: Data {
        try! JSONSerialization.data(withJSONObject: dummyDic, options: .prettyPrinted)
    }
}
