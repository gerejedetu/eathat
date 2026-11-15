@testable import Eathat
import Foundation

/// Answers every request with the same body and remembers the requests.
actor FakeHTTPClient: HTTPClient {
    let answer: Data
    private(set) var requests: [HTTPRequest] = []

    init(answer: String) {
        self.answer = Data(answer.utf8)
    }

    func send(_ request: HTTPRequest) throws -> Data {
        requests.append(request)
        return answer
    }
}
