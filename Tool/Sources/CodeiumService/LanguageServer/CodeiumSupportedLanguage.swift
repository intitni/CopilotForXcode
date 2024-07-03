import Foundation
import SuggestionBasic

enum CodeiumSupportedLanguage: Int, Codable {
    case unspecified = 0
    case c = 1
    case clojure = 2
    case coffeescript = 3
    case cpp = 4
    case csharp = 5
    case css = 6
    case cudacpp = 7
    case dockerfile = 8
    case go = 9
    case groovy = 10
    case handlebars = 11
    case haskell = 12
    case hcl = 13
    case html = 14
    case ini = 15
    case java = 16
    case javascript = 17
    case json = 18
    case julia = 19
    case kotlin = 20
    case latex = 21
    case less = 22
    case lua = 23
    case makefile = 24
    case markdown = 25
    case objectivec = 26
    case objectivecpp = 27
    case perl = 28
    case php = 29
    case plaintext = 30
    case protobuf = 31
    case pbtxt = 32
    case python = 33
    case r = 34
    case ruby = 35
    case rust = 36
    case sass = 37
    case scala = 38
    case scss = 39
    case shell = 40
    case sql = 41
    case starlark = 42
    case swift = 43
    case tsx = 44
    case typescript = 45
    case visualbasic = 46
    case vue = 47
    case xml = 48
    case xsl = 49
    case yaml = 50
    case svelte = 51
    case toml = 52
    case dart = 53
    case rst = 54
    case ocaml = 55
    case cmake = 56
    case pascal = 57
    case elixir = 58
    case fsharp = 59
    case lisp = 60
    case matlab = 61
    case powershell = 62
    case solidity = 63
    case ada = 64
    case ocaml_interface = 65
    
    init(codeLanguage: CodeLanguage) {
        switch codeLanguage {
        case let .builtIn(language):
            switch language {
            case .abap:
                self = .unspecified
            case .windowsbat:
                self = .unspecified
            case .bibtex:
                self = .unspecified
            case .clojure:
                self = .clojure
            case .coffeescript:
                self = .coffeescript
            case .c:
                self = .c
            case .cpp:
                self = .cpp
            case .csharp:
                self = .csharp
            case .css:
                self = .css
            case .diff:
                self = .unspecified
            case .dart:
                self = .dart
            case .dockerfile:
                self = .dockerfile
            case .elixir:
                self = .elixir
            case .erlang:
                self = .unspecified
            case .fsharp:
                self = .fsharp
            case .gitcommit:
                self = .unspecified
            case .gitrebase:
                self = .unspecified
            case .go:
                self = .go
            case .groovy:
                self = .groovy
            case .handlebars:
                self = .handlebars
            case .html:
                self = .html
            case .ini:
                self = .ini
            case .java:
                self = .java
            case .javascript:
                self = .javascript
            case .javascriptreact:
                self = .javascript
            case .json:
                self = .json
            case .latex:
                self = .latex
            case .less:
                self = .less
            case .lua:
                self = .lua
            case .makefile:
                self = .makefile
            case .markdown:
                self = .markdown
            case .objc:
                self = .objectivec
            case .objcpp:
                self = .objectivecpp
            case .perl:
                self = .perl
            case .perl6:
                self = .unspecified
            case .php:
                self = .php
            case .powershell:
                self = .powershell
            case .pug:
                self = .unspecified
            case .python:
                self = .python
            case .r:
                self = .r
            case .razor:
                self = .unspecified
            case .ruby:
                self = .ruby
            case .rust:
                self = .rust
            case .scss:
                self = .scss
            case .sass:
                self = .sass
            case .scala:
                self = .scala
            case .shaderlab:
                self = .unspecified
            case .shellscript:
                self = .shell
            case .sql:
                self = .sql
            case .swift:
                self = .swift
            case .typescript:
                self = .typescript
            case .typescriptreact:
                self = .tsx
            case .tex:
                self = .latex
            case .vb:
                self = .visualbasic
            case .xml:
                self = .xml
            case .xsl:
                self = .xsl
            case .yaml:
                self = .yaml
            }
        case .plaintext:
            self = .plaintext
        case let .other(name):
            switch name {
            case "svelte":
                self = .svelte
            case "toml":
                self = .toml
            case "rst":
                self = .rst
            case "lisp":
                self = .lisp
            case "matlab":
                self = .matlab
            default:
                self = .unspecified
            }
        }
    }
}
