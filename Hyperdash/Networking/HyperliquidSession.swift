import Foundation

/// One Hyperliquid environment, resolved once. Holds the client bound to its
/// network and the shared meta cache; everything that talks to the API
/// receives a session instead of re-deriving network → client at each layer.
struct HyperliquidSession {
    let network: HyperliquidNetwork
    let client: HyperliquidClient
    let meta: MetaService

    init(network: HyperliquidNetwork, transport: HTTPTransport = URLSessionTransport()) {
        self.network = network
        self.client = HyperliquidClient(network: network, transport: transport)
        self.meta = MetaService(client: client)
    }

    var info: InfoService {
        InfoService(client: client, meta: meta)
    }

    func exchange(agentKeyHex: String) throws -> ExchangeService {
        try ExchangeService(network: network, client: client, agentKeyHex: agentKeyHex)
    }
}
