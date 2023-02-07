// menu.swift - renders menu bar items as Alfred results
// (c) Benzi Ahamed, 2017

// The aim of this workflow is to provide the *fastest* possible
// ux for searching and actioning menu bar items of the app specified
// in Alfred using Swift

import Cocoa
import Foundation
import SwiftProtobuf

Alfred.preparePaths()

let args = RuntimeArgs()
args.parse()

// get application details

var app: NSRunningApplication?
if args.pid == -1 {
    app = NSWorkspace.shared.menuBarOwningApplication
}
else {
    app = NSRunningApplication(processIdentifier: args.pid)
}

guard let app = app else { Alfred.quit("Unable to get app info") }
let appPath = app.bundleURL?.path ?? app.executableURL?.path ?? "icon.png"
let appLocalizedName = app.localizedName ?? "no-name"
let appBundleId = app.bundleIdentifier ?? "no-id"
let appDisplayName = "\(appLocalizedName) (\(appBundleId))"
let axApp = AXUIElementCreateApplication(app.processIdentifier)

// try to get a reference to the menu bar
let menuBar = MenuBar(for: app)
switch menuBar.initState {
case .success:
    break

case .apiDisabled:
    Alfred.quit("Assistive applications are not enabled in System Preferences.", subtitle: "Is accessibility enabled for Alfred?")

case .noValue:
    Alfred.quit("No menu bar", subtitle: "\(appDisplayName) does not have a native menu bar")

default:
    Alfred.quit("Could not get menu bar", subtitle: "An error occured \(menuBar.initState.rawValue)")
}

// if we need to click a menu path
// then do that
if let clickIndices = args.clickIndices, clickIndices.count > 0 {
    menuBar.click(pathIndices: clickIndices)
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
                    Alfred.quit("Menu search disabled!", subtitle: "\(appDisplayName)", icon: "icon.error.png")
                }

                args.options.appFilter = appOverride
                if args.options.appFilter.cacheDuration > 0 {
                    args.cacheTimeout = args.options.appFilter.cacheDuration
                    args.cachingEnabled = true
                }
                else {
                    args.cachingEnabled = false
                }
            }
        }
        catch let error as TextFormatDecodingError {
            Alfred.quit("\(error)", subtitle: "Settings Error")
        }
        catch {
            Alfred.quit("Invalid settings file", subtitle: settingsPath)
        }
    }
    else {
        Alfred.quit("Invalid settings file", subtitle: settingsPath)
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

if args.cachingEnabled, let items = Cache.load(app: appBundleId, settingsModifiedInterval: settingsModifiedInterval) {
    // caching enabled and we were able to load information
    menuItems = items
}
else {
    if args.loadAsync {
        menuItems = menuBar.loadAsync(args.options)
    }
    else {
        menuItems = menuBar.load(args.options)
    }
    if args.cachingEnabled {
        Cache.save(app: appBundleId, items: menuItems, lifetime: args.cacheTimeout)
    }
}

// filter menu items and render result

// func r(_ menu: MenuItem) -> () {
func render(_ menu: MenuItem) {
    let apple = menu.appleMenuItem
    a.add(.with {
        $0.uid = args.learning ? "\(appBundleId)>\(menu.uid)" : ""
        $0.title = menu.shortcut.isEmpty ? menu.title : "\(menu.title) - \(menu.shortcut)"
        $0.subtitle = menu.subtitle
        $0.arg = menu.arg
        $0.icon.path = apple ? "apple-icon.png" : appPath
        $0.icon.type = apple ? "" : "fileicon"
    })
}
let r = render // prevent swiftc compiler segfault

func transferToShortcut(from term: inout String) -> () {
    if !term.hasPrefix("#") || term.count < 2{
        return
    } 
    term = String(term.dropFirst())
    var res = [String]()
    if term.contains("ctrl") { res.append("⌃") }
    if term.contains("alt") { res.append("⌥") }
    if term.contains("shift") { res.append("⇧") }
    if term.contains("cmd") { res.append("⌘") }
    if term.split(separator: " ").last!.count == 1 {
        term = res.joined(separator: halfWidthSpace) + halfWidthSpace + term.split(separator: " ").last!
    } else {
        term = res.joined(separator: halfWidthSpace)
    }
}

if !args.query.isEmpty {
    let term = args.query.lowercased()
    transferToShortcut(from: &term)
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
                let name = menu.searchPath[level].lowercased() + " " + menu.shortcut.lowercased()
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
                    let r = menu.searchPath[level].textMatch(term: term)
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
else if args.options.appFilter.showAppleMenu, args.reorderAppleMenuToLast, menuItems.count > 0 {
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
        $0.icon = .with { $0.path = "icon.error.png" }
    })
}

print(a.resultsJson)
