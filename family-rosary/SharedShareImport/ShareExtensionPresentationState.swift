import Foundation

enum ShareExtensionPresentationState: Equatable {
    case processing
    case success
    case failure(message: String)
}

struct ShareExtensionPresentationStateController {
    private(set) var state: ShareExtensionPresentationState = .processing

    mutating func transitionToSuccess() {
        state = .success
    }

    mutating func transitionToFailure(message: String) {
        state = .failure(message: message)
    }
}
