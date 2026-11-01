import CryptoKit
import Foundation

private let romSetupIntl = ROMSetupIntl()

/// Owns an ephemeral download session and verifies every firmware part before returning owned bytes.
/// Start, cancel and completions are main-thread operations; cancelled transfers deliver no further completion.
final class ROMDownload {
    private let session: URLSession
    private var cancelled = false
    private var parts: [(String, String)] = []
    private var collected = Data()
    private var completion: ((Result<Data, Error>) -> Void)?

    init(configuration: URLSessionConfiguration = .ephemeral) {
        self.session = URLSession(configuration: configuration)
    }

    deinit { session.invalidateAndCancel() }

    func start(_ parts: [(String, String)], completion: @escaping (Result<Data, Error>) -> Void) {
        self.parts = parts
        self.completion = completion
        DispatchQueue.main.async { [weak self] in self?.next(0) }
    }

    func cancel() {
        cancelled = true
        completion = nil
        session.invalidateAndCancel()
    }

    private func next(_ index: Int) {
        guard !cancelled else { return }
        if index == parts.count {
            completion?(.success(collected))
            completion = nil
            return
        }

        let part = parts[index]
        var request = URLRequest(
            url: URL(
                string:
                    ROMLibrary.mirror + part.0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!)!
        )
        request.timeoutInterval = 30
        session.dataTask(with: request) { [weak self] data, response, failure in
            DispatchQueue.main.async { [weak self] in
                guard let self = self, !self.cancelled else { return }
                if let failure = failure {
                    self.completion?(.failure(failure))
                } else if let data = data, let response = response as? HTTPURLResponse,
                    response.statusCode == 200,
                    SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == part.1
                {
                    self.collected.append(data)
                    self.next(index + 1)
                    return
                } else {
                    self.completion?(.failure(ROMLibrary.error(romSetupIntl.theDownloadCouldNotBeVerified)))
                }
                self.completion = nil
            }
        }.resume()
    }
}
