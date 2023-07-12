import Foundation
import SwiftUI
import AppKit
import ASTParser
import PlaygroundSupport

struct ParsingForm: View {
    @State var filePath: String = ""
    @State var result: String = ""
    
    var body: some View {
        Form {
            Section("Input") {
                TextField("File Path", text: $filePath)
                Button("Parse") {
                    result = ""
                    Task {
                        let fileContent = try String(contentsOfFile: filePath)
                        let parser = ASTParser(language: .swift)
                        let tree = parser.parse(fileContent)
                        result = tree?.dump() ?? "N/A"
                    }
                }
            }
            
            Section("Result") {
                Text(result)
                    .fontDesign(.monospaced)
            }
        }
        .formStyle(.grouped)
        .frame(width: 600, height: 800)
    }
}

PlaygroundPage.current.needsIndefiniteExecution = true
PlaygroundPage.current.setLiveView(NSHostingController(rootView: ParsingForm()))
