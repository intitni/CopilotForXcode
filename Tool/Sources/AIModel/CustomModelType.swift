import Foundation

public enum CustomModelType: String, CaseIterable {
    case completionModel
    case fimModel
    case tabby
    
    public static var `default`: CustomModelType {
        .completionModel
    }
}
