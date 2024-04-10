import Foundation
import SharedUIComponents
import SwiftUI

#if canImport(ProHostApp)
import ProHostApp
#endif

struct XcodeSettingsView: View {
    var body: some View {
        VStack {
            #if canImport(ProHostApp)
            CloseXcodeIdleTabsSettingsView()
            #endif

            EmptyView()
        }
    }
}

