import XCTest
@testable import Hyperdash

private final class FakeUbiquitousStore: UbiquitousKeyValueStoring {
    private(set) var values: [String: Any] = [:]
    private(set) var synchronizeCount = 0

    func data(forKey defaultName: String) -> Data? {
        values[defaultName] as? Data
    }

    func set(_ value: Any?, forKey defaultName: String) {
        values[defaultName] = value
    }

    func removeObject(forKey defaultName: String) {
        values.removeValue(forKey: defaultName)
    }

    func synchronize() -> Bool {
        synchronizeCount += 1
        return true
    }
}

@MainActor
final class WalletStoreTests: XCTestCase {
    private let address = "0x7e5f4552091a69125d5dfcb7b8c2659029395bdf"

    func testSyncOffDoesNotWriteWalletsToCloud() throws {
        let defaults = makeDefaults()
        let cloud = FakeUbiquitousStore()
        let store = WalletStore(
            defaults: defaults,
            ubiquitous: cloud,
            iCloudSyncEnabled: false,
            observeExternalChanges: false
        )

        try store.add(name: "Main", address: address, agentKeyHex: nil, synchronizable: false)

        XCTAssertNotNil(defaults.data(forKey: "wallets.v1"))
        XCTAssertNil(cloud.data(forKey: "wallets.v1"))
    }

    func testSyncOnWritesWalletsToCloud() throws {
        let defaults = makeDefaults()
        let cloud = FakeUbiquitousStore()
        let store = WalletStore(
            defaults: defaults,
            ubiquitous: cloud,
            iCloudSyncEnabled: true,
            observeExternalChanges: false
        )

        try store.add(name: "Main", address: address, agentKeyHex: nil, synchronizable: true)

        XCTAssertNotNil(defaults.data(forKey: "wallets.v1"))
        XCTAssertNotNil(cloud.data(forKey: "wallets.v1"))
    }

    func testLoadIgnoresCloudWhenSyncIsOff() throws {
        let defaults = makeDefaults()
        let cloud = FakeUbiquitousStore()
        defaults.set(try encode([Wallet(name: "Local", address: address)]), forKey: "wallets.v1")
        cloud.set(try encode([Wallet(name: "Cloud", address: address)]), forKey: "wallets.v1")

        let store = WalletStore(
            defaults: defaults,
            ubiquitous: cloud,
            iCloudSyncEnabled: false,
            observeExternalChanges: false
        )

        XCTAssertEqual(store.wallets.map(\.name), ["Local"])
    }

    func testLoadPrefersCloudWhenSyncIsOn() throws {
        let defaults = makeDefaults()
        let cloud = FakeUbiquitousStore()
        defaults.set(try encode([Wallet(name: "Local", address: address)]), forKey: "wallets.v1")
        cloud.set(try encode([Wallet(name: "Cloud", address: address)]), forKey: "wallets.v1")

        let store = WalletStore(
            defaults: defaults,
            ubiquitous: cloud,
            iCloudSyncEnabled: true,
            observeExternalChanges: false
        )

        XCTAssertEqual(store.wallets.map(\.name), ["Cloud"])
    }

    func testEnablingSyncPushesLocalWalletsToCloud() throws {
        let defaults = makeDefaults()
        let cloud = FakeUbiquitousStore()
        let store = WalletStore(
            defaults: defaults,
            ubiquitous: cloud,
            iCloudSyncEnabled: false,
            observeExternalChanges: false
        )
        try store.add(name: "Main", address: address, agentKeyHex: nil, synchronizable: false)

        store.setiCloudSyncEnabled(true, migrateKeys: false)

        let cloudWallets = try decode(cloud.data(forKey: "wallets.v1"))
        XCTAssertEqual(cloudWallets.map(\.name), ["Main"])
        XCTAssertGreaterThan(cloud.synchronizeCount, 0)
    }

    func testDisablingSyncRemovesCloudWallets() throws {
        let defaults = makeDefaults()
        let cloud = FakeUbiquitousStore()
        let store = WalletStore(
            defaults: defaults,
            ubiquitous: cloud,
            iCloudSyncEnabled: true,
            observeExternalChanges: false
        )
        try store.add(name: "Main", address: address, agentKeyHex: nil, synchronizable: true)

        store.setiCloudSyncEnabled(false, migrateKeys: false)

        XCTAssertNil(cloud.data(forKey: "wallets.v1"))
        XCTAssertNotNil(defaults.data(forKey: "wallets.v1"))
    }

    func testExternalCloudUpdateOnlyAppliesWhenSyncIsEnabled() throws {
        let defaults = makeDefaults()
        let cloud = FakeUbiquitousStore()
        let store = WalletStore(
            defaults: defaults,
            ubiquitous: cloud,
            iCloudSyncEnabled: false,
            observeExternalChanges: false
        )
        try store.add(name: "Local", address: address, agentKeyHex: nil, synchronizable: false)
        cloud.set(try encode([Wallet(name: "Cloud", address: address)]), forKey: "wallets.v1")

        store.handleExternaliCloudChange()
        XCTAssertEqual(store.wallets.map(\.name), ["Local"])

        store.setiCloudSyncEnabled(true, migrateKeys: false)
        cloud.set(try encode([Wallet(name: "Cloud", address: address)]), forKey: "wallets.v1")
        store.handleExternaliCloudChange()

        XCTAssertEqual(store.wallets.map(\.name), ["Cloud"])
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "WalletStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func encode(_ wallets: [Wallet]) throws -> Data {
        try JSONEncoder().encode(wallets)
    }

    private func decode(_ data: Data?) throws -> [Wallet] {
        try JSONDecoder().decode([Wallet].self, from: XCTUnwrap(data))
    }
}
