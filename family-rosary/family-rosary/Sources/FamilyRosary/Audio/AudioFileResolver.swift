import Foundation

protocol AudioFileResolving {
    func resolve(personID: String, token: String) -> URL?
}
