import Foundation
import SuggestionModel
import XcodeInspector

func getEditorInformation() -> EditorInformation? {
    return XcodeInspector.shared.getFocusedEditorContent()
}

