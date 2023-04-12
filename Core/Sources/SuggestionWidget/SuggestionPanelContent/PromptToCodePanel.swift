import MarkdownUI
import SwiftUI

struct PromptToCodePanel: View {
    @ObservedObject var provider: PromptToCodeProvider
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    if provider.code.isEmpty {
                        Text(
                            provider.isResponding
                                ? "Thinking..."
                                : "Enter your requirement to generate code."
                        )
                        .foregroundColor(.secondary)
                        .padding()
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    } else {
                        CodeBlock(
                            code: provider.code,
                            language: provider.language,
                            startLineIndex: provider.startLineIndex,
                            colorScheme: colorScheme,
                            firstLinePrecedingSpaceCount: provider.startLineColumn
                        )
                        .frame(maxWidth: .infinity)
                    }

                    if !provider.description.isEmpty {
                        Markdown(provider.description)
                            .textSelection(.enabled)
                            .markdownTheme(.gitHub.text {
                                BackgroundColor(Color.clear)
                            })
                            .padding()
                            .frame(maxWidth: .infinity)
                    }

                    if !provider.errorMessage.isEmpty {
                        Text(provider.errorMessage)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red)
                    }

                    Spacer(minLength: 50)
                }
            }
            .overlay(alignment: .bottom) {
                Group {
                    if provider.isResponding {
                        Button(action: {
                            provider.stopResponding()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "stop.fill")
                                Text("Stop Responding")
                            }
                            .padding(8)
                            .background(
                                .regularMaterial,
                                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        HStack {
                            Button(action: {
                                provider.cancel()
                            }) {
                                Text("Cancel")
                            }.buttonStyle(CommandButtonStyle(color: .gray))

                            if !provider.code.isEmpty {
                                Button(action: {
                                    provider.acceptSuggestion()
                                }) {
                                    Text("Accept")
                                }.buttonStyle(CommandButtonStyle(color: .indigo))
                            }
                        }
                        .padding(8)
                        .background(
                            .regularMaterial,
                            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        }
                    }
                }
                .padding(.bottom, 8)
            }

            PromptToCodePanelToolbar(provider: provider)
        }
        .background(Color.contentBackground)
        .xcodeStyleFrame()
    }
}

struct PromptToCodePanelToolbar: View {
    @ObservedObject var provider: PromptToCodeProvider
    @FocusState var isInputAreaFocused: Bool

    var body: some View {
        HStack {
            Button(action: {
                provider.revert()
            }) {
                Group {
                    Image(systemName: "arrow.uturn.backward")
                }
                .padding(6)
                .background {
                    Circle().fill(Color(nsColor: .controlBackgroundColor))
                }
                .overlay {
                    Circle()
                        .stroke(Color(nsColor: .controlColor), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .disabled(provider.isResponding)

            HStack(spacing: 0) {
                Group {
                    if #available(macOS 13.0, *) {
                        TextField("Requriement", text: $provider.requirement, axis: .vertical)
                    } else {
                        TextEditor(text: $provider.requirement)
                            .frame(height: 42, alignment: .leading)
                            .font(.body)
                            .background(Color.clear)
                    }
                }
                .focused($isInputAreaFocused)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .textFieldStyle(.plain)
                .padding(8)
                .onSubmit {
                    provider.sendRequirement()
                }

                Button(action: {
                    provider.sendRequirement()
                }) {
                    Image(systemName: "paperplane.fill")
                        .padding(8)
                }
                .buttonStyle(.plain)
                .disabled(provider.isResponding)
            }
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .controlBackgroundColor))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(nsColor: .controlColor), lineWidth: 1)
            }
        }
        .onAppear {
            isInputAreaFocused = true
        }
        .padding(8)
        .background(.ultraThickMaterial)
    }
}

// MARK: - Previews

struct PromptToCodePanel_Bright_Preview: PreviewProvider {
    static var previews: some View {
        PromptToCodePanel(provider: PromptToCodeProvider(
            code: """
            ForEach(0..<viewModel.suggestion.count, id: \\.self) { index in
                Text(viewModel.suggestion[index])
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }
            """,
            language: "swift",
            description: "Hello world",
            isResponding: false,
            startLineIndex: 8
        ))
        .preferredColorScheme(.light)
        .frame(width: 450, height: 400)
    }
}
