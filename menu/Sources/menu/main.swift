// menu.swift - renders menu bar items as Alfred results
// (c) Benzi Ahamed, 2017

// The aim of this workflow is to provide the *fastest* possible
// ux for searching and actioning menu bar items of the app specified
// in Alfred using Swift

import Cocoa
import Foundation
import SwiftProtobuf

Alfred.preparePaths()

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
options.maxDepth = 10
options.maxChildren = 40
options.appFilter = AppFilter()

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
let createBoolFromInt: (String)->Bool? = { (value) in
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

while let arg = current {
    switch arg {
    case "-pid":
        advance()
        pid = parse(createInt32, "Expected integer after -pid")

    case "-query", "-q":
        advance()
        if let arg = current {
            advance()
            query = arg.lowercased()
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
        a.add(AlfredResultItem.with { $0.title = "Settings Folder"; $0.arg = Alfred.data() })
        if !FileManager.default.fileExists(atPath: Alfred.data(path: "settings.txt")) {
            a.add(AlfredResultItem.with {
                $0.title = "View a sample Settings file"
                $0.subtitle = "You can use this as a reference to customise per app configuration"
                $0.arg = "sample settings.txt"
            })
        }
        a.add(AlfredResultItem.with {
            $0.title = "Cache Folder"
            $0.arg = Alfred.cache()
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

// get application details

var app: NSRunningApplication?
if pid == -1 {
    app = NSWorkspace.shared.menuBarOwningApplication
}
else {
    app = NSRunningApplication(processIdentifier: pid)
}

guard let app = app else { Alfred.quit("Unable to get app info") }
let appPath = app.bundleURL?.path ?? app.executableURL?.path ?? "icon.png"
let appLocalizedName = app.localizedName ?? "no-name"
let appBundleId = app.bundleIdentifier ?? "no-id"
let appDisplayName = "\(appLocalizedName) (\(appBundleId))"
let axApp = AXUIElementCreateApplication(app.processIdentifier)

// try to get a reference to the menu bar

var menuBarValue: CFTypeRef?
let result = AXUIElementCopyAttributeValue(axApp, kAXMenuBarAttribute as CFString, &menuBarValue)
switch result {
case .success:
    break

case .apiDisabled:
    Alfred.quit("Assistive applications are not enabled in System Preferences.", "Is accessibility enabled for Alfred?")

case .noValue:
    Alfred.quit("No menu bar", "\(appDisplayName) does not have a native menu bar")

default:
    Alfred.quit("Could not get menu bar", "An error occured \(result.rawValue)")
}

// try to get all menu items

let menuBar = menuBarValue as! AXUIElement

// if we need to click a menu path
// then do that
if let clickIndices = clickIndices, clickIndices.count > 0 {
    clickMenu(menu: menuBar, pathIndices: clickIndices, currentIndex: 0)
    Cache.invalidate(app: appBundleId)
    exit(0)
}

var settingsModifiedInterval: Double?
let fm = FileManager.default
let settingsPath = Alfred.data(path: "settings.txt")
if fm.fileExists(atPath: settingsPath) {
    if let attributes = try? fm.attributesOfItem(atPath: settingsPath),
       let mod = attributes[.modificationDate] as? Date,
       // let settingsData = try? Data.init(contentsOf: .init(fileURLWithPath: settingsPath))
       let settingsText = try? String(contentsOfFile: settingsPath)
    {
        do {
            let settings = try Settings(textFormatString: settingsText)
            // we have a custom settings file
            // record timestamp of when we last modified it
            // all caches created before this timestamp are stale
            settingsModifiedInterval = mod.timeIntervalSince1970

            // if we find a specific filter for the current app
            // store that in the options
            if let i = settings.appFilters.firstIndex(where: { $0.app == appBundleId }) {
                let appOverride = settings.appFilters[i]

                if appOverride.disabled {
                    Alfred.quit("Menu Search disabled for \(appDisplayName)")
                }

                options.appFilter = appOverride
                if options.appFilter.cacheDuration > 0 {
                    cacheTimeout = options.appFilter.cacheDuration
                    cachingEnabled = true
                }
                else {
                    cachingEnabled = false
                }
            }
        }
        catch let error as TextFormatDecodingError {
            Alfred.quit("\(error)", "Settings Error")
        }
        catch {
            Alfred.quit("Invalid settings file", settingsPath)
        }
    }
    else {
        Alfred.quit("Invalid settings file", settingsPath)
    }
}

// print("options.appFilter.showAppleMenu", options.appFilter.showAppleMenu)

// do {
//    var s = Settings()
//    var f = AppFilter()
//    f.app = "Terminal"
//    f.ignorePaths.append(MenuPath.with { $0.path = ["Shell"] } )
//    s.appFilters = [f]
//    print(try! s.jsonString())
// }

let menuItems: [MenuItem]
let a = Alfred()

if cachingEnabled, let items = Cache.load(app: appBundleId, settingsModifiedInterval: settingsModifiedInterval) {
    // caching enabled and we were able to load information
    menuItems = items
}
else {
    if loadAsync {
        menuItems = MenuGetter.loadAsync(menuBar: menuBar, options: options)
    }
    else {
        menuItems = MenuGetter.loadSync(menuBar: menuBar, options: options)
    }
    if cachingEnabled {
        Cache.save(app: appBundleId, items: menuItems, lifetime: cacheTimeout)
    }
}

// filter menu items and render result

// func r(_ menu: MenuItem) -> () {
func render(_ menu: MenuItem) {
    let apple = menu.appleMenuItem
    a.add(.with {
        $0.uid = learning ? "\(appBundleId)>\(menu.uid)" : ""
        $0.title = menu.shortcut.isEmpty ? menu.title : "\(menu.title) - \(menu.shortcut)"
        $0.subtitle = menu.subtitle
        $0.arg = menu.arg
        $0.icon.path = apple ? "apple-icon.png" : appPath
        $0.icon.type = apple ? "" : "fileicon"
    })
}

let r = render // prevent swiftc compiler segfault

if !query.isEmpty {
    let term = query.lowercased()
    let rankedMenuItems: [(MenuItem, Int)] =
        menuItems
            .lazy
            .map { (menu: MenuItem)->(MenuItem, Int) in
                // finds the first ranked path component
                // if we have File -> New Tab
                // and we enter "file", we must match "file"
                // we enter "nt", we must match "new tab"
                // work our way starting from the leaf menu path
                // and upwards until a ranked match is found

                // for the last item alone, do a fuzzy match
                // along with normal ranked search
                var level = menu.path.count - 1
                let name = menu.path[level].lowercased()
                let rank = name.textMatch(term: term)
                var rankAdjust = 4096
                if rank == 100 {
                    // only if it starts with
                    // because fuzzyScore may be larger
                    return (menu, rank + rankAdjust)
                }
                let fuzzyScore = name.fuzzyMatch(term: term)
                let score = max(fuzzyScore, rank)
                if score > 0 {
                    return (menu, score + rankAdjust)
                }

                // normally rank the other path components
                level -= 1
                while level >= 0 {
                    rankAdjust /= 2
                    let r = menu.path[level].lowercased().textMatch(term: term)
                    if r > 0 {
                        return (menu, r + rankAdjust)
                    }
                    level -= 1
                }

                // no matches at all
                return (menu, 0)
            }
            .sorted(by: { a, b in a.1 > b.1 })

    // scan through sorted list, add items as long
    // as we have rank > 0, break off the moment
    // we reach an item with rank 0
    var i = 0
    while i < rankedMenuItems.endIndex {
        let item = rankedMenuItems[i]
        if item.1 == 0 {
            break // all remaining ones will also be ranked 0, since its sorted
        }
        r(item.0)
        i += 1
    }
}
else if options.appFilter.showAppleMenu, reorderAppleMenuToLast, menuItems.count > 0 {
    // rearrange so that Apple menu items are last
    // do not use filter as its slow with unnecessary copying
    // instead we find
    // the index of menu items which is not a apple menu
    // then display all items from that range
    // followed by all items in the starting range

    // yes this is more verbose code, but faster
    // i..<j will be apple menu items
    // j..<end will be app menu items

    let end = menuItems.endIndex
    if let i = menuItems.firstIndex(where: { $0.appleMenuItem }) {
        var j = i + 1
        while j < end, menuItems[j].appleMenuItem {
            j += 1
        }
        if i > 0 {
            menuItems[0..<i].forEach { r($0) }
        }
        if j < end {
            menuItems[j..<end].forEach { r($0) }
        }
        // print all apple items
        menuItems[i..<j].forEach { r($0) }
    }
    else {
        // no apple menu item at the start?
        // print everything
        // ideally we do not get here
        menuItems.forEach { r($0) }
    }
}
else {
    // no search query, no reorder of menu items
    menuItems.forEach { r($0) }
}

if a.results.items.count == 0 {
    // a.add(.with { item in item.title = "No menu items" })
    a.add(AlfredResultItem.with {
        $0.title = "No menu items"
    })
}

print(a.resultsJson)
