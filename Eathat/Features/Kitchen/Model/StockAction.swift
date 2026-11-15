import Foundation

/// A quick action on a stock line, sent to `POST /v1/stock/{id}/{action}`.
nonisolated enum StockAction: Equatable, Sendable {
    /// Eaten or used; `nil` takes all that is left.
    case consume(quantity: Double?)
    /// Thrown away; `nil` takes all that is left.
    case waste(quantity: Double?, reason: String?)
    case open
    case move(StorageLocation)
    /// The real date read on the pack, 'YYYY-MM-DD'.
    case setBestBefore(String)

    /// The JSON the API expects for this action; absent fields are left out.
    struct Payload: Encodable, Equatable {
        var quantity: Double?
        var reason: String?
        var location: StorageLocation?
        var bestBefore: String?
    }

    var pathComponent: String {
        switch self {
        case .consume: "consume"
        case .waste: "waste"
        case .open: "open"
        case .move: "move"
        case .setBestBefore: "best-before"
        }
    }

    var payload: Payload {
        switch self {
        case let .consume(quantity): Payload(quantity: quantity)
        case let .waste(quantity, reason): Payload(quantity: quantity, reason: reason)
        case .open: Payload()
        case let .move(location): Payload(location: location)
        case let .setBestBefore(day): Payload(bestBefore: day)
        }
    }
}
