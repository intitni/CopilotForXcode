import ActiveApplicationMonitor
import Combine
import PromptToCodeService
import SuggestionWidget

extension PromptToCodeProvider {
    convenience init(
        service: PromptToCodeService,
        name: String?,
        onClosePromptToCode: @escaping () -> Void
    ) {
        self.init(
            code: service.code,
            language: service.language.rawValue,
            description: "",
            attachedToRange: service.selectionRange,
            name: name
        )

        var cancellables = Set<AnyCancellable>()

        service.$code.sink(receiveValue: set(\.code)).store(in: &cancellables)
        service.$isResponding.sink(receiveValue: set(\.isResponding)).store(in: &cancellables)
        service.$description.sink(receiveValue: set(\.description)).store(in: &cancellables)
        service.$isContinuous.sink(receiveValue: set(\.isContinuous)).store(in: &cancellables)
        service.$history.map { $0 != .empty }
            .sink(receiveValue: set(\.canRevert)).store(in: &cancellables)
        service.$selectionRange.sink(receiveValue: set(\.attachedToRange)).store(in: &cancellables)

        onCancelTapped = { [cancellables] in
            _ = cancellables
            service.stopResponding()
            onClosePromptToCode()
        }

        onRevertTapped = {
            service.revert()
        }

        onRequirementSent = { [weak self] requirement in
            Task { [weak self] in
                do {
                    try await service.modifyCode(prompt: requirement)
                } catch is CancellationError {
                    return
                } catch {
                    Task { @MainActor [weak self] in
                        self?.errorMessage = error.localizedDescription
                    }
                }
            }
        }

        onStopRespondingTap = {
            service.stopResponding()
        }

        onAcceptSuggestionTapped = { [weak self] in
            Task { [weak self] in
                let handler = PseudoCommandHandler()
                await handler.acceptPromptToCode()
                if let app = ActiveApplicationMonitor.shared.previousApp,
                   app.isXcode,
                   !(self?.isContinuous ?? false)
                {
                    try await Task.sleep(nanoseconds: 200_000_000)
                    app.activate()
                }
            }
        }

        onContinuousToggleClick = {
            service.isContinuous.toggle()
        }

        onToggleAttachOrDetachToCode = {
            service.toggleAttachOrDetachToCode()
        }
    }

    func set<T>(_ keyPath: WritableKeyPath<PromptToCodeProvider, T>) -> (T) -> Void {
        return { [weak self] value in
            Task { @MainActor [weak self] in
                self?[keyPath: keyPath] = value
            }
        }
    }
}

