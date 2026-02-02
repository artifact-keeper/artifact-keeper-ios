import Foundation
import Alamofire

actor APIClient {
    static let shared = APIClient()

    private let baseURL: String
    private let session: Session

    init(baseURL: String = "") {
        self.baseURL = baseURL
        self.session = Session()
    }

    func request<T: Decodable>(
        _ endpoint: String,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil
    ) async throws -> T {
        try await session.request(
            "\(baseURL)\(endpoint)",
            method: method,
            parameters: parameters,
            encoding: JSONEncoding.default
        )
        .serializingDecodable(T.self)
        .value
    }
}
