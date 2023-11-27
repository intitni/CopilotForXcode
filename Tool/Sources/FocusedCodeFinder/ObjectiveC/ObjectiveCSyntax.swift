import Foundation

/// https://github.com/lukepistrol/tree-sitter-objc/blob/feature/spm/test/corpus/imports.txt
/// https://github.com/lukepistrol/tree-sitter-objc/blob/feature/spm/test/corpus/expressions.txt
/// https://github.com/lukepistrol/tree-sitter-objc/blob/feature/spm/test/corpus/declarations.txt
/// https://github.com/lukepistrol/tree-sitter-objc/blob/feature/spm/node-types.json
/// Some of the test cases are actually incorrect?
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
    case classDeclarationList = "class_declaration_list"
    /// ```
    /// + (tr)k1: (t1)a1 : (t2)a2 k2: a3;
    /// ```
    case propertyDeclaration = "property_declaration"
    /// ```objc
    /// + (tr)k1: (t1)a1 : (t2)a2 k2: a3;
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
    /// Fields inside a type definition.
    case fieldDeclarationList = "field_declaration_list"
    /// Protocols that a type conforms.
    case protocolQualifiers = "protocol_qualifiers"
    /// Superclass of a type.
    case superclassReference = "superclass_reference"
    /// The generic type arguments.
    case parameterizedClassTypeArguments = "parameterized_class_type_arguments"
    /// `__GENERICS` in category interface and implementation.
    case genericsTypeReference = "generics_type_reference"
    /// `IB_DESIGNABLE`, etc. The typo is from the original source.
    case classInterfaceAttributeSpecifier = "class_interface_attribute_sepcifier"
}

extension ObjectiveCNodeType {
    init?(rawValue: String?) {
        self.init(rawValue: rawValue ?? "")
    }
}
