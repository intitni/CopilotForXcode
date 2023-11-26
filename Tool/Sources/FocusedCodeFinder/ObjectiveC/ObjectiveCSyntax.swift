import Foundation

/// https://github.com/merico-dev/tree-sitter-objc/test/corpus/imports.txt
/// https://github.com/merico-dev/tree-sitter-objc/test/corpus/expressions.txt
/// https://github.com/merico-dev/tree-sitter-objc/test/corpus/declarations.txt
/// https://github.com/merico-dev/tree-sitter-objc/node-types.json
enum ObjectiveCNodeType: String {
    /// The top most item
    case translationUnit = "translation_unit"
    /// `#include`
    case preprocInclude = "preproc_include"
    /// `#import "bar.h"`
    case preprocImport = "preproc_import"
    /// `@import foo.bar`
    case moduleImport = "module_import"
    /// ```objc
    /// @interface ClassName(Category)<Protocol1, Protocol2>: SuperClass {
    ///   type1 iv1;
    ///   type2 iv2;
    /// }
    /// @property (readwrite, copy) float value;
    /// + (tr)k1:(t1)a1 : (t2)a2 k2: a3;
    /// @end
    /// ```
    ///
    /// will parse into:
    /// ```
    /// (translation_unit
    ///   (class_interface
    ///     name: (identifier)
    ///     superclass: (identifier)))              < SuperClass
    ///     protocols: (protocol_reference_list     < Protocols
    ///       (identifier)
    ///       (identifier))))
    ///     (field_declaration                      < iv1
    ///       type: (type_identifier)
    ///       declarator: (field_identifier))
    ///     (field_declaration                      < iv2
    ///       type: (type_identifier)
    ///       declarator: (field_identifier))))
    ///     (property_declaration ...)              < property value
    ///     (method_declaration ...)                < method
    /// ```
    ///
    case classInterface = "class_interface"
    /// `@implementation`
    case classImplementation = "class_implementation"
    /// Similar to class interface.
    case categoryInterface = "category_interface"
    /// Similar to class implementation.
    case categoryImplementation = "category_implementation"
    /// Similar to class interface.
    case protocolDeclaration = "protocol_declaration"
    /// `@protocol <P1, P2>`
    case protocolDeclarationList = "protocol_declaration_list"
    /// ```objc
    /// @class C1, C2;
    /// ```
    ///
    /// will parse into:
    /// ```
    /// (translation_unit
    ///   (class_declaration_list
    ///     (identifier)
    ///     (identifier)))
    /// ```
    case classDeclarationList = "class_declaration_list"
    /// ```
    /// + (tr)k1: (t1)a1 : (t2)a2 k2: a3;
    /// ```
    ///
    /// will parse into:
    /// ```
    /// (property_declaration
    ///   (readwrite)
    ///   (copy)
    ///   type: (type_identifier)                   < type
    ///   name: (identifier))))                     < name
    /// ```
    case propertyDeclaration = "property_declaration"
    /// ```objc
    /// + (tr)k1: (t1)a1 : (t2)a2 k2: a3;
    /// ```
    ///
    /// will parse into:
    /// ```
    /// (method_declaration
    ///   scope: (class_scope)
    ///   return_type: (type_descriptor
    ///   type: (type_identifier))
    ///   selector: (keyword_selector
    ///   (keyword_declarator
    ///       keyword: (identifier)
    ///       type: (type_descriptor
    ///           type: (type_identifier))
    ///       name: (identifier))
    ///   (keyword_declarator
    ///       type: (type_descriptor
    ///           type: (type_identifier))
    ///       name: (identifier))
    ///   (keyword_declarator
    ///       keyword: (identifier)
    ///       name: (identifier))))))
    /// ```
    case methodDeclaration = "method_declaration"
    /// `- (rt)sel {}`
    case methodDefinition = "method_definition"
    /// function definitions
    case functionDefinition = "function_definition"
    /// Names of symbols
    case identifier = "identifier"
    /// Type identifiers
    case typeIdentifier = "type_identifier"
    /// Compound statements, such as `{ ... }`
    case compoundStatement = "compound_statement"
    /// Typedef.
    case typeDefinition = "type_definition"
    /// `struct {}`.
    case structSpecifier = "struct_specifier"
    /// `enum {}`.
    case enumSpecifier = "enum_specifier"
    /// `NS_ENUM {}` and `NS_OPTIONS {}`.
    case nsEnumSpecifier = "ns_enum_specifier"
    /// fields inside a type definition.
    case fieldDeclarationList = "field_declaration_list"
}

extension ObjectiveCNodeType {
    init?(rawValue: String?) {
        self.init(rawValue: rawValue ?? "")
    }
}
