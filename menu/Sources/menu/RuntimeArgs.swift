//
//  RuntimeArgs.swift
//  
//
//  Created by Benzi  on 20/12/2022.
//

import Foundation

class RuntimeArgs {
    // process command line args
    // every argument is optional
    // [-query <filter>] - filter menu listing based on filter
    // [-pid <id>] - target app with specified pid, if none, menubar owning app is detected
    // [-max-depth <depth:10>]  - max traversal depth of app menu
    // [-max-children <count:20>] -  max set of child menu items to process under parent menu
    // -reorder-apple-menu (true|false:true) - by default, orders Apple menu items to the last
    // -learning  (true|false:true)
    // -click <json_index_path_to_menu_item> - clicks the menu path for the given pid app
    // -async - enable GCD based collection of sub menu items
    // -cache <timeout> - enable caching with specified timeout interval
    // -no-apple-menu - disable outputing apple menu items
    // -show-disabled true/false - if enabled, displays menu items that are marked as disabled
    // -dump - prints out debug dump, if present output from menu will not be compatible with Alfred

    var query = ""
    var pid: Int32 = -1
    var reorderAppleMenuToLast = true
    var learning = true
    var clickIndices: [Int]?
    var loadAsync = false
    var cachingEnabled = false
    var cacheTimeout = 0.0

    var options = MenuGetterOptions()

    var i = 1 // skip name of program
    var current: String? {
        return i < CommandLine.arguments.count ? CommandLine.arguments[i] : nil
    }

    func advance() {
        i += 1
    }

    let createInt: (String)->Int? = { Int($0) }
    let createInt32: (String)->Int32? = { Int32($0) }
    let createBool: (String)->Bool? = { Bool($0) }
    let createDouble: (String)->Double? = { Double($0) }
    let createBoolFromInt: (String)->Bool? = { value in
        if let v = Int(value), v == 1 {
            return true
        }
        return false
    }

    func parse<T>(_ create: (String)->T?, _ error: String)->T {
        if let arg = current, let value = create(arg) {
            advance()
            return value
        }
        Alfred.quit(error)
    }

    func parseOptional<T>(_ create: (String)->T?, _ fallback: T)->T {
        if let arg = current {
            advance()
            return create(arg) ?? fallback
        }
        return fallback
    }

    func parse() {
        
        options.maxDepth = 10
        options.maxChildren = 40
        options.appFilter = AppFilter()
        
        while let arg = current {
            switch arg {
            case "-pid":
                advance()
                pid = parse(createInt32, "Expected integer after -pid")

            case "-query", "-q":
                advance()
                if let arg = current {
                    advance()
                    query = arg.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: nil)
                }

            case "-max-depth":
                advance()
                options.maxDepth = parse(createInt, "Expected number after -max-depth")

            case "-max-children":
                advance()
                options.maxChildren = parse(createInt, "Expected number after -max-children")

            case "-cache":
                advance()
                cachingEnabled = true
                cacheTimeout = parse(createDouble, "Expected timeout after -cache")

            case "-reorder-apple-menu":
                advance()
                reorderAppleMenuToLast = parse(createBool, "Expected true/false after -reorder-apple-menu")

            case "-learning":
                advance()
                learning = parse(createBool, "Expected true/false after -learning")

            case "-click":
                advance()
                guard let pathJson = current else {
                    Alfred.quit("Not able to parse argument after -click \(CommandLine.arguments)")
                    break
                }
                advance()
                clickIndices = IndexParser.parse(pathJson)

            case "-async":
                advance()
                loadAsync = true

            case "-show-apple-menu":
                advance()
                options.appFilter.showAppleMenu = parse(createBoolFromInt, "Expected 0/1 after -show-apple-menu")

            case "-only":
                advance()
                guard let specificMenuRoot = current else {
                    Alfred.quit("Expected root menu name after -only")
                    break
                }
                options.specificMenuRoot = specificMenuRoot

            case "-show-disabled":
                advance()
                options.appFilter.showDisabledMenuItems = parse(createBoolFromInt, "Expected 0/1 after -show-disabled")

            case "-dump":
                advance()
                options.dumpInfo = true

            case "-show-folders":
                let a = Alfred()
                let icon = AlfredResultItemIcon.with { $0.path = "icon.settings.png" }
                a.add(AlfredResultItem.with {
                    $0.title = "Settings Folder"
                    $0.arg = Alfred.data()
                    $0.icon = icon
                })
                if !FileManager.default.fileExists(atPath: Alfred.data(path: "settings.txt")) {
                    a.add(AlfredResultItem.with {
                        $0.title = "View a sample Settings file"
                        $0.subtitle = "You can use this as a reference to customise per app configuration"
                        $0.arg = "sample settings.txt"
                        $0.icon = icon
                    })
                }
                a.add(AlfredResultItem.with {
                    $0.title = "Cache Folder"
                    $0.arg = Alfred.cache()
                    $0.icon = icon
                })
        //        for cache in Cache.getCachedMenuControls() {
        //            let expiry = Date(timeIntervalSince1970: cache.control.timeout)
        //            let now = Date()
        //            let expirationPrefix = expiry > now ? "expires" : "expired"
        //            if #available(macOS 10.15, *) {
        //                let formatter = RelativeDateTimeFormatter()
        //                a.add(AlfredResultItem.with {
        //                    $0.title = cache.appBundleId
        //                    $0.subtitle = "\(expirationPrefix): \(formatter.localizedString(for: expiry, relativeTo: Date()))"
        //                })
        //            }
        //            else {
        //                a.add(AlfredResultItem.with {
        //                    $0.title = cache.appBundleId
        //                    $0.subtitle = "\(expirationPrefix): \(expiry)"
        //                })
        //            }
        //        }
                print(a.resultsJson)
                exit(0)

            default:
                // unknown command line option
                advance()
            }
        }
    }
}
