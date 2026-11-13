import CryptoKit
import Flutter
import Security
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // The attendance device key (ADR-D). Registered through the same plugin
    // registry `GeneratedPluginRegistrant` uses, so it is bound to the same
    // engine and does not depend on the window's root view controller.
    if let registrar = self.registrar(forPlugin: "EsasDeviceKeyChannel") {
      DeviceKeyChannel.register(with: registrar)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

/// The attendance device key (ADR-D §5, §10): one EC P-256 signing key per
/// account on this install, tagged with the alias Dart derives from the
/// workspace and the user (PO 4.2.8), so a second account or another workspace
/// never uses or replaces it. On a handset it lives in the Secure Enclave, is
/// usable only while the device is unlocked, and is `ThisDeviceOnly`: never
/// synced to iCloud and never restored to another device. The simulator has no Secure Enclave, so there it is a software
/// keychain key and is reported as `hardwareBackedClaimed: false`.
///
/// Same methods and error codes as the Android `DeviceKeyChannel`.
final class DeviceKeyChannel {
  static let channelName = "esas/device_key"

  /// What Dart may name a key: short, and nothing a keychain query could misread.
  private static func tag(_ alias: String) -> Data? {
    guard !alias.isEmpty, alias.count <= 128,
      alias.unicodeScalars.allSatisfy({
        CharacterSet.alphanumerics.contains($0) && $0.isASCII || "._-".unicodeScalars.contains($0)
      })
    else {
      return nil
    }
    return Data(alias.utf8)
  }

  /// DER prefix that turns a 65-byte X9.63 P-256 point into X.509
  /// SubjectPublicKeyInfo: SEQUENCE { SEQUENCE { id-ecPublicKey, prime256v1 },
  /// BIT STRING (0 unused bits) }.
  private static let spkiHeader: [UInt8] = [
    0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01,
    0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07, 0x03, 0x42, 0x00,
  ]

  private struct KeyError: Error {
    let code: String
    let message: String
  }

  private let queue = DispatchQueue(label: "esas.device_key", qos: .userInitiated)

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    let instance = DeviceKeyChannel()
    channel.setMethodCallHandler { call, result in
      instance.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    queue.async {
      let reply: Any?
      let arguments = call.arguments as? [String: Any]

      do {
        switch call.method {
        case "capabilities":
          let alias = arguments?["alias"] as? String
          reply = self.capabilities(tag: alias.flatMap(Self.tag))
        case "generate":
          reply = try self.generate(
            tag: try Self.requiredTag(arguments),
            replace: (arguments?["replace"] as? Bool) ?? false
          )
        case "publicKey":
          reply = try self.publicKey(tag: try Self.requiredTag(arguments))
        case "sign":
          let tag = try Self.requiredTag(arguments)
          guard let bytes = arguments?["bytes"] as? FlutterStandardTypedData else {
            throw KeyError(code: "INVALID_ARGUMENT", message: "bytes is required")
          }
          reply = try self.sign(bytes.data, tag: tag)
        case "delete":
          self.delete(tag: try Self.requiredTag(arguments))
          reply = nil
        case "exists":
          reply = self.privateKey(tag: try Self.requiredTag(arguments)) != nil
        default:
          DispatchQueue.main.async { result(FlutterMethodNotImplemented) }
          return
        }
      } catch let error as KeyError {
        DispatchQueue.main.async {
          result(FlutterError(code: error.code, message: error.message, details: nil))
        }
        return
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "KEY_UNAVAILABLE", message: nil, details: nil))
        }
        return
      }

      DispatchQueue.main.async { result(reply) }
    }
  }

  private static func requiredTag(_ arguments: [String: Any]?) throws -> Data {
    guard let alias = arguments?["alias"] as? String else {
      throw KeyError(code: "INVALID_ARGUMENT", message: "alias is required")
    }
    guard let tag = tag(alias) else {
      throw KeyError(code: "INVALID_ARGUMENT", message: "alias is malformed")
    }
    return tag
  }

  // MARK: - Methods

  private func capabilities(tag: Data?) -> [String: Any] {
    let existing = tag.flatMap { privateKey(tag: $0) }
    let claimed = existing.map(isSecureEnclaveKey) ?? SecureEnclave.isAvailable

    return [
      "available": true,
      "hardwareBackedClaimed": claimed,
      "strongBox": false,
      "platform": "ios",
    ]
  }

  /// Create the key, or describe the existing one. An existing key is replaced
  /// only when [replace] is true.
  private func generate(tag: Data, replace: Bool) throws -> [String: Any] {
    if let existing = privateKey(tag: tag) {
      if !replace {
        return describe(existing)
      }
      delete(tag: tag)
    }

    return describe(try createKey(tag: tag))
  }

  /// The public key as X.509 SubjectPublicKeyInfo DER, base64 (standard).
  private func publicKey(tag: Data) throws -> String {
    guard let key = privateKey(tag: tag) else {
      throw KeyError(code: "KEY_MISSING", message: "no key under the tag")
    }
    guard let publicKey = SecKeyCopyPublicKey(key) else {
      throw KeyError(code: "KEY_UNAVAILABLE", message: "no public key")
    }

    var error: Unmanaged<CFError>?
    guard let point = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
      _ = error?.takeRetainedValue()
      throw KeyError(code: "KEY_UNAVAILABLE", message: "public key not exportable")
    }
    guard point.count == 65, point.first == 0x04 else {
      throw KeyError(code: "KEY_UNAVAILABLE", message: "unexpected public key encoding")
    }

    return (Data(Self.spkiHeader) + point).base64EncodedString()
  }

  /// ECDSA P-256 with SHA-256 over exactly [message]; DER signature, base64.
  private func sign(_ message: Data, tag: Data) throws -> String {
    guard let key = privateKey(tag: tag) else {
      throw KeyError(code: "KEY_MISSING", message: "no key under the tag")
    }

    let algorithm = SecKeyAlgorithm.ecdsaSignatureMessageX962SHA256
    guard SecKeyIsAlgorithmSupported(key, .sign, algorithm) else {
      throw KeyError(code: "KEY_UNAVAILABLE", message: "algorithm not supported")
    }

    var error: Unmanaged<CFError>?
    guard let signature = SecKeyCreateSignature(key, algorithm, message as CFData, &error) as Data?
    else {
      _ = error?.takeRetainedValue()
      throw KeyError(code: "KEY_UNAVAILABLE", message: "signing failed")
    }

    return signature.base64EncodedString()
  }

  private func delete(tag: Data) {
    let query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecAttrApplicationTag as String: tag,
    ]
    SecItemDelete(query as CFDictionary)
  }

  // MARK: - Keychain

  private func privateKey(tag: Data) -> SecKey? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassKey,
      kSecAttrApplicationTag as String: tag,
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
      kSecReturnRef as String: true,
    ]

    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
      let found = item
    else {
      return nil
    }

    // A keychain query for kSecReturnRef on kSecClassKey answers a SecKey.
    return (found as! SecKey)
  }

  private func createKey(tag: Data) throws -> SecKey {
    if SecureEnclave.isAvailable {
      do {
        return try createSecureEnclaveKey(tag: tag)
      } catch {
        #if targetEnvironment(simulator)
          return try createSoftwareKey(tag: tag)
        #else
          throw error
        #endif
      }
    }

    return try createSoftwareKey(tag: tag)
  }

  private func createSecureEnclaveKey(tag: Data) throws -> SecKey {
    var error: Unmanaged<CFError>?

    guard
      let access = SecAccessControlCreateWithFlags(
        kCFAllocatorDefault,
        kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        .privateKeyUsage,
        &error
      )
    else {
      _ = error?.takeRetainedValue()
      throw KeyError(code: "KEY_UNAVAILABLE", message: "access control")
    }

    let attributes: [String: Any] = [
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecAttrKeySizeInBits as String: 256,
      kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
      kSecPrivateKeyAttrs as String: [
        kSecAttrIsPermanent as String: true,
        kSecAttrApplicationTag as String: tag,
        kSecAttrAccessControl as String: access,
      ] as [String: Any],
    ]

    guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
      _ = error?.takeRetainedValue()
      throw KeyError(code: "KEY_UNAVAILABLE", message: "secure enclave key not created")
    }

    return key
  }

  /// The simulator (or a device without a Secure Enclave): a P-256 key in the
  /// software keychain, reported as not hardware-backed.
  private func createSoftwareKey(tag: Data) throws -> SecKey {
    var error: Unmanaged<CFError>?

    let attributes: [String: Any] = [
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecAttrKeySizeInBits as String: 256,
      kSecPrivateKeyAttrs as String: [
        kSecAttrIsPermanent as String: true,
        kSecAttrApplicationTag as String: tag,
        kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
      ] as [String: Any],
    ]

    guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
      _ = error?.takeRetainedValue()
      throw KeyError(code: "KEY_UNAVAILABLE", message: "software key not created")
    }

    return key
  }

  private func describe(_ key: SecKey) -> [String: Any] {
    return [
      "available": true,
      "hardwareBackedClaimed": isSecureEnclaveKey(key),
      "strongBox": false,
      "platform": "ios",
    ]
  }

  private func isSecureEnclaveKey(_ key: SecKey) -> Bool {
    guard let attributes = SecKeyCopyAttributes(key) as? [String: Any] else {
      return false
    }

    return (attributes[kSecAttrTokenID as String] as? String)
      == (kSecAttrTokenIDSecureEnclave as String)
  }
}
