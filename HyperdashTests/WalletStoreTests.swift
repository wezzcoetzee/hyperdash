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
    private let storageKey = "wallets.v1"

    private lazy var defaults: UserDefaults = {
        let suite = "WalletStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return defaults
    }()
    private let cloud = FakeUbiquitousStore()

    private func makeStore(sync: Bool = false, cloud: FakeUbiquitousStore? = nil) -> WalletStore {
        WalletStore(defaults: defaults, ubiquitous: cloud ?? self.cloud,
                    iCloudSyncEnabled: sync, observeExternalChanges: false)
    }

    private func add(_ name: String, to store: WalletStore, key: String? = nil) throws {
        try store.add(name: name, address: address, agentKeyHex: key, synchronizable: false)
    }

    func testSyncOffDoesNotWriteWalletsToCloud() throws {
        try add("Main", to: makeStore(sync: false))

        XCTAssertNotNil(defaults.data(forKey: storageKey))
        XCTAssertNil(cloud.data(forKey: storageKey))
    }

    func testSyncOnWritesWalletsToCloud() throws {
        try add("Main", to: makeStore(sync: true))

        XCTAssertNotNil(defaults.data(forKey: storageKey))
        XCTAssertNotNil(cloud.data(forKey: storageKey))
    }

    func testLoadReadsCloudOnlyWhenSyncIsOn() throws {
        defaults.set(try encode([Wallet(name: "Local", address: address)]), forKey: storageKey)
        cloud.set(try encode([Wallet(name: "Cloud", address: address)]), forKey: storageKey)

        XCTAssertEqual(makeStore(sync: false).wallets.map(\.name), ["Local"])
        XCTAssertEqual(makeStore(sync: true).wallets.map(\.name), ["Cloud"])
    }

    func testEnablingSyncPushesLocalWalletsToCloud() throws {
        let store = makeStore(sync: false)
        try add("Main", to: store)

        store.setiCloudSyncEnabled(true, migrateKeys: false)

        let cloudWallets = try JSONDecoder().decode([Wallet].self, from: XCTUnwrap(cloud.data(forKey: storageKey)))
        XCTAssertEqual(cloudWallets.map(\.name), ["Main"])
        XCTAssertGreaterThan(cloud.synchronizeCount, 0)
    }

    func testDisablingSyncRemovesCloudWallets() throws {
        let store = makeStore(sync: true)
        try add("Main", to: store)

        store.setiCloudSyncEnabled(false, migrateKeys: false)

        XCTAssertNil(cloud.data(forKey: storageKey))
        XCTAssertNotNil(defaults.data(forKey: storageKey))
    }

    func testExternalCloudUpdateOnlyAppliesWhenSyncIsEnabled() throws {
        let store = makeStore(sync: false)
        try add("Local", to: store)
        cloud.set(try encode([Wallet(name: "Cloud", address: address)]), forKey: storageKey)

        store.handleExternaliCloudChange()
        XCTAssertEqual(store.wallets.map(\.name), ["Local"])

        store.setiCloudSyncEnabled(true, migrateKeys: false)
        cloud.set(try encode([Wallet(name: "Cloud", address: address)]), forKey: storageKey)
        store.handleExternaliCloudChange()

        XCTAssertEqual(store.wallets.map(\.name), ["Cloud"])
    }

    /// The estimated agent-key expiry counts from this timestamp.
    func testAddWithKeySetsKeyAddedAt() throws {
        let store = makeStore()
        try add("Main", to: store, key: "0x0000000000000000000000000000000000000000000000000000000000000001")
        XCTAssertNotNil(store.wallets.first?.keyAddedAt)
    }

    func testDecodesLegacyWalletWithoutKeyAddedAt() throws {
        let json = #"[{"id":"\#(UUID().uuidString)","name":"Legacy","address":"\#(address)"}]"#
        let wallets = try JSONDecoder().decode([Wallet].self, from: Data(json.utf8))
        XCTAssertEqual(wallets.count, 1)
        XCTAssertNil(wallets.first?.keyAddedAt)
        XCTAssertEqual(wallets.first?.icon, .wallet)
    }

    func testMovePersistsNewOrder() throws {
        let store = makeStore()
        for name in ["First", "Second", "Third"] { try add(name, to: store) }

        store.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)

        XCTAssertEqual(store.wallets.map(\.name), ["Third", "First", "Second"])
        XCTAssertEqual(makeStore(cloud: FakeUbiquitousStore()).wallets.map(\.name), ["Third", "First", "Second"])
    }

    private func encode(_ wallets: [Wallet]) throws -> Data {
        try JSONEncoder().encode(wallets)
    }
}
