import Foundation

/// Loads bounded artwork bytes and returns completion on the main thread; image decoding belongs to presentation.
struct ArtworkLoader {
    let session: URLSession

    init(session: URLSession = .shared) { self.session = session }

    func load(_ url: URL, completion: @escaping (Data?) -> Void) {
        session.dataTask(with: url) { data, _, _ in
            let result = data.flatMap { $0.count <= 30 * 1024 * 1024 ? $0 : nil }
            DispatchQueue.main.async { completion(result) }
        }.resume()
    }
}
