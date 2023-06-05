import Foundation

public var userDefaultSuiteName: String {
    "5YKZ4Y3DAW.group.com.intii.CopilotForXcode"
}

public var keychainAccessGroup: String {
    #if DEBUG
    return "5YKZ4Y3DAW.dev.com.intii.CopilotForXcode.Shared"
    #else
    return "5YKZ4Y3DAW.com.intii.CopilotForXcode.Shared"
    #endif
}

public var keychainService: String {
    #if DEBUG
    return "dev.com.intii.CopilotForXcode"
    #else
    return "com.intii.CopilotForXcode"
    #endif
}

