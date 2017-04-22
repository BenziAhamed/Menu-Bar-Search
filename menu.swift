// menu.swift - renders menu bar items as Alfred results
// (c) Benzi Ahamed, 2017

// The aim of this workflow is to provide the *fastest* possible
// ux for searching and actioning menu bar items of the app specified
// in Alfred using Swift

import Foundation
import Cocoa

let fm = FileManager.default

struct TextSearch {    
    
    let term: String
    
    init(term: String) {
        self.term = term
    }

    func rank(for text: String) -> Int {
        if text.hasPrefix(term) {
            return 100
        }
        if text.contains(term) {
            return 10
        }
        return 0
    }
}

extension String {
    var fuzzyIndex : String {
        
        var f = ""
        let alphaNum = CharacterSet.alphanumerics
        let whitespace = CharacterSet.whitespaces
        
        var waitingForSpace = false
        for c in self.unicodeScalars {
            if alphaNum.contains(c), !waitingForSpace {
                f.append(String(c))
                waitingForSpace = true
            }
            else if waitingForSpace, whitespace.contains(c) {
                waitingForSpace = false
            }
        }
        
        return f
    }
}

class Alfred {

    static func preparePaths() {
        try? fm.createDirectory(atPath: data(), withIntermediateDirectories: false, attributes: nil)
        try? fm.createDirectory(atPath: cache(), withIntermediateDirectories: false, attributes: nil)
    }
    
    static func data(path: String? = nil) -> String {
        return folder(type: "data", path: path)
    }
    static func cache(path: String? = nil) -> String {
        return folder(type: "cache", path: path)
    }
    static func folder(type: String, path: String? = nil) -> String {
        let base = ProcessInfo().environment["alfred_workflow_\(type)"] ?? "."
        guard let path = path else { return base }
        return "\(base)/\(path)"
    }
    static func env(_ name: String) -> String? {
        return ProcessInfo().environment[name]
    }
    
    var results = [[String: Any]]()
    
    func add(uid: String? = nil, type: String? = nil, title: String? = nil, subtitle: String? = nil, arg: String? = nil, autocomplete: String? = nil, iconPath: String? = nil, iconType: String? = nil) {
        
        var s = [String: Any]()

        uid.flatMap { s["uid"] = $0 }
        type.flatMap { s["type"] = $0 }
        title.flatMap { s["title"] = $0 }
        subtitle.flatMap { s["subtitle"] = $0 }
        arg.flatMap { s["arg"] = $0 }
        autocomplete.flatMap { s["autocomplete"] = $0 }
        
        if arg == nil {
            s["valid"] = false
        }
        
        if iconType != nil || iconPath != nil {
            s["icon"] = [
                "type": iconType,
                "path": iconPath
            ]
        }

        results.append(s)
    }
    
    func output() -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: results, options: []),
            let output = String.init(data: data, encoding: String.Encoding.utf8) else {
                return "{\"items\": []}"
        }
        return "{\"items\":\(output)}"
    }

    static func quit(_ title: String, _ subtitle: String? = nil) -> Never {
        let a = Alfred()
        a.add(title: title, subtitle: subtitle)
        print(a.output())
        exit(0)
    }

}


let virtualKeys = [
    0x24: "↩", // kVK_Return
    0x4C: "⌤", // kVK_ANSI_KeypadEnter
    0x47: "⌧", // kVK_ANSI_KeypadClear
    0x30: "⇥", // kVK_Tab
    0x31: "␣", // kVK_Space
    0x33: "⌫", // kVK_Delete
    0x35: "⎋", // kVK_Escape
    0x39: "⇪", // kVK_CapsLock
    0x3F: "fn", // kVK_Function
    0x7A: "F1", // kVK_F1
    0x78: "F2", // kVK_F2
    0x63: "F3", // kVK_F3
    0x76: "F4", // kVK_F4
    0x60: "F5", // kVK_F5
    0x61: "F6", // kVK_F6
    0x62: "F7", // kVK_F7
    0x64: "F8", // kVK_F8
    0x65: "F9", // kVK_F9
    0x6D: "F10", // kVK_F10
    0x67: "F11", // kVK_F11
    0x6F: "F12", // kVK_F12
    0x69: "F13", // kVK_F13
    0x6B: "F14", // kVK_F14
    0x71: "F15", // kVK_F15
    0x6A: "F16", // kVK_F16
    0x40: "F17", // kVK_F17
    0x4F: "F18", // kVK_F18
    0x50: "F19", // kVK_F19
    0x5A: "F20", // kVK_F20
    0x73: "↖", // kVK_Home
    0x74: "⇞", // kVK_PageUp
    0x75: "⌦", // kVK_ForwardDelete
    0x77: "↘", // kVK_End
    0x79: "⇟", // kVK_PageDown
    0x7B: "←", // kVK_LeftArrow
    0x7C: "→", // kVK_RightArrow
    0x7D: "↓", // kVK_DownArrow
    0x7E: "↑", // kVK_UpArrow
]

func decode(modifiers: Int) -> String {
    if modifiers == 0x18 { return "fn fn" }
    var result = ""
    if (modifiers & 0x04) > 0 { result.append("^") }
    if (modifiers & 0x02) > 0 { result.append("⌥") }
    if (modifiers & 0x01) > 0 { result.append("⇧") }
    if (modifiers & 0x08) == 0 { result.append("⌘") }
    return result
}

func getShortcut(_ cmd: String?, _ modifiers: Int, _ virtualKey: Int) -> String? {
    var shortcut: String? = cmd
    if let s = shortcut {
        if s.unicodeScalars[s.unicodeScalars.startIndex].value == 0x7f {
            shortcut = "⌦"
        }
    }
    else if virtualKey > 0 {
        if let lookup = virtualKeys[virtualKey] {
            shortcut = lookup
        }
    }
    let mods = decode(modifiers: modifiers)
    if let s = shortcut {
       shortcut = mods + s
    }
    return shortcut
}

func getAttribute(element: AXUIElement, name: String) -> CFTypeRef? {
    var value: CFTypeRef? = nil
    AXUIElementCopyAttributeValue(element, name as CFString, &value)
    return value
}

struct MenuItem {

    var path: [String]
    var pathIndices: String
    var shortcut: String? = nil
    var fuzzyIndex: String = ""

    func array() -> [Any] {
        var d = [Any]()
        d.append(path)
        d.append(pathIndices)
        d.append(fuzzyIndex)
        shortcut.flatMap { d.append($0) }
        return d
    }

    init(path: [String], pathIndices: String, shortcut: String?) {
        self.path = path
        self.pathIndices = pathIndices
        self.shortcut = shortcut
        path.last.flatMap {
            self.fuzzyIndex = $0.fuzzyIndex.lowercased()
        }
    }

    init(array a: [Any]) {
        path = a[0] as? [String] ?? []
        pathIndices = a[1] as? String ?? ""
        fuzzyIndex = a[2] as? String ?? ""
        if a.count == 4 {
            shortcut = a[3] as? String ?? ""
        }
    }
    
    var arg: String {
        return "[\(pathIndices)]"
    }

    var uid: String {
        return path.joined(separator: ">")
    }

    var appleMenuItem: Bool {
        return path[0] == "Apple" 
    }

    var subtitle: String {
        var p = path
        p.removeLast()
        return p.joined(separator: " > ")
    }
    
    var title: String {
        return path.last!
    }    
}

// cache 
struct MenuItemCache {

    static func getPaths(_ app: String) -> (String, String) {
        let base = app
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return (
            Alfred.cache(path: "\(base).txt"),
            Alfred.cache(path: "\(base).items.txt")
        )
    }

    static func write(object: Any, path: String) {
        guard let data = try? JSONSerialization.data(
                withJSONObject: object,
                options: []
            ),
            let string = String(data: data, encoding: .utf8)
            else { return }

        do {
            try string.write(toFile: path, atomically: false, encoding: .utf8)
        } catch { } 

    }

    static func save(app: String, items: [MenuItem]) {
        // save timestamp info to app.txt
        // save item info to app.items.txt
        let (controlPath, itemsPath) = getPaths(app)
        let control: [Any] = [ app, Date().timeIntervalSince1970 ]
        let items = items.map { $0.array() }
        write(object: control, path: controlPath)
        write(object: items, path: itemsPath)
    }

    static func read(path: String) -> Any? {
        let url = URL.init(fileURLWithPath: path)
        guard let data = try? Data.init(contentsOf: url),
            let json = try? JSONSerialization.jsonObject(with: data, options: [.mutableContainers])
            else { return nil }
        return json
    }

    static func load(app: String, timeout: Double) -> [MenuItem]? {
        let (controlPath, itemsPath) = getPaths(app)
        guard let control = read(path: controlPath) as? [Any],
            control.count == 2,
            let controlApp = control[0] as? String,
            controlApp == app,
            let timestamp = control[1] as? Double
            else { 
                return nil 
            }
        let timeoutBy = Date().timeIntervalSince1970 - timestamp
        if timeoutBy > timeout {
            // if we timedout within 1 second
            // slide the timeout window forward
            // this allows us to reuse the cache if we are close
            if timeoutBy - 1 < timeout {
                extend(app: app, timestamp: timestamp + 3, controlPath: controlPath)
            }
            else {
                // too stale data, invalidate for sure
                return nil
            }
        }
        guard let items = read(path: itemsPath) as? [[Any]]
            else { return nil }
        return items.map { MenuItem(array: $0) }
    }

    static func extend(app: String, timestamp: Double, controlPath: String) {
        let control: [Any] = [ app, timestamp ]
        write(object: control, path: controlPath)
    }

    static func invalidate(app: String) {
        let (controlPath, _) = getPaths(app)
        guard fm.isDeletableFile(atPath: controlPath) else { return }
        try? fm.removeItem(atPath: controlPath)
    }

}

func clickMenu(menu element: AXUIElement, pathIndices: [Int], currentIndex: Int) {
    guard let menuBarItems = getAttribute(element: element, name: kAXChildrenAttribute) as? [AXUIElement], menuBarItems.count > 0 else { return }
    let itemIndex = pathIndices[currentIndex]
    guard itemIndex >= menuBarItems.startIndex, itemIndex < menuBarItems.endIndex else { return }
    let child = menuBarItems[itemIndex]
    if currentIndex == pathIndices.count - 1 {
        AXUIElementPerformAction(child, kAXPressAction as CFString)
        return
    }
    guard let menuBar = getAttribute(element: child, name: kAXChildrenAttribute) as? [AXUIElement] else { return }
    clickMenu(menu: menuBar[0], pathIndices: pathIndices, currentIndex: currentIndex + 1)
}

func getMenuItems(
    forElement element: AXUIElement,
    menuItems: inout [MenuItem],
    path: [String] = [],
    pathIndices: String = "",
    depth: Int = 0,
    maxDepth: Int = 10,
    maxChildren: Int = 20
    ) {
    guard depth < maxDepth else { return }
    guard let children = getAttribute(element: element, name: kAXChildrenAttribute) as? [AXUIElement], children.count > 0 else { return }
    var processedChildrenCount = 0
    for i in children.indices {
        let child = children[i]
        guard let enabled = getAttribute(element: child, name: kAXEnabledAttribute) as? Bool, enabled else { continue }
        guard let name = getAttribute(element: child, name: kAXTitleAttribute) as? String else { continue }
        guard !name.isEmpty else { continue }
        guard let children = getAttribute(element: child, name: kAXChildrenAttribute) as? [AXUIElement] else { continue }
        
        if children.count == 1 {
            // sub-menu item, scan children
            getMenuItems(
                forElement: children[0],
                menuItems: &menuItems,
                path: path + [name],
                pathIndices: pathIndices.isEmpty ? "\(i)" : pathIndices + ",\(i)",
                depth: depth + 1,
                maxDepth: maxDepth,
                maxChildren: maxChildren

            )
        }
        else {
            // not a sub menu, if we have a path to this item
            let cmd = getAttribute(element: child, name: kAXMenuItemCmdCharAttribute) as? String
            var modifiers: Int = 0
            var virtualKey: Int = 0
            if let m = getAttribute(element: child, name: kAXMenuItemCmdModifiersAttribute) {
                CFNumberGetValue(m as! CFNumber, CFNumberType.longType, &modifiers)
            }
            if let v = getAttribute(element: child, name: kAXMenuItemCmdVirtualKeyAttribute) {
                CFNumberGetValue(v as! CFNumber, CFNumberType.longType, &virtualKey)
            }


            menuItems.append(MenuItem(
                path: path + [name],
                pathIndices: pathIndices.isEmpty ? "\(i)" : pathIndices + ",\(i)",
                shortcut: getShortcut(cmd, modifiers, virtualKey)
            ))
        }
        
        processedChildrenCount += 1
        if processedChildrenCount > maxChildren {
            break
        }
    }
}


struct AsyncMenu {
    static func load(menuBar: AXUIElement, maxDepth: Int = 10, maxChildren: Int = 20) -> [MenuItem] {
        var menuItems = [MenuItem]()
        let q: DispatchQueue
        if #available(macOS 10.10, *) {
            q = DispatchQueue(label: "folded-paper.menu-bar", qos: .userInteractive, attributes: .concurrent)
        }
        else {
            q = DispatchQueue(label: "folded-paper.menu-bar", attributes: .concurrent)
        }
        let group = DispatchGroup()
        guard let menuBarItems = getAttribute(element: menuBar, name: kAXChildrenAttribute) as? [AXUIElement],
            menuBarItems.count > 0 else { return [] }
        for i in menuBarItems.indices {
            let item = menuBarItems[i]
            guard let name = getAttribute(element: item, name: kAXTitleAttribute) as? String else { continue }
            guard let children = getAttribute(element: item, name: kAXChildrenAttribute) as? [AXUIElement] else { continue }
            q.async(group: group) {
                var items = [MenuItem]()
                getMenuItems(
                    forElement: children[0],
                    menuItems: &items,
                    path: [name],
                    pathIndices: "\(i)",
                    depth: 1,
                    maxDepth: maxDepth,
                    maxChildren: maxChildren
                )
                q.async(group: group, flags: .barrier) {
                    menuItems.append(contentsOf: items)
                }
            }
        }
        _ = group.wait(timeout: .distantFuture)
        return menuItems
    }
}

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

var query = ""
var pid: Int32 = -1
var maxDepth = 10
var maxChildren = 20
var reorderAppleMenuToLast = true
var learning = true
var clickIndices: [Int]? = nil
var loadAsync = false
var cachingEnabled = false
var cacheTimeout = 0.0

var i = 1 // skip name of program
var current: String? {
    return i < CommandLine.arguments.count ? CommandLine.arguments[i] : nil
}
func advance() {
    i += 1
}

let createInt:(String)->Int? = { Int($0) }
let createInt32:(String)->Int32? = { Int32($0) }
let createBool:(String)->Bool? = { Bool($0) }
let createDouble:(String)->Double? = { Double($0) }

func parse<T>(_ create: (String)->T?, _ error: String) -> T {
    if let arg = current, let value = create(arg) {
        advance()
        return value
    }
    Alfred.quit(error)
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
            maxDepth = parse(createInt, "Expected count after -max-depth")

        case "-max-children":
            advance()
            maxChildren = parse(createInt, "Expected count after -max-children")

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
            guard let pathJson = current,
                   let data = pathJson.data(using: .utf8),
                   let jsonObject = try? JSONSerialization.jsonObject(with: data, options: [.mutableContainers]),
                   let pathIndices = jsonObject as? [Int]
                    else {
                        Alfred.quit("Not able to parse argument after -click \(CommandLine.arguments)")
                        break
                    }
            
            advance()
            clickIndices = pathIndices

        case "-async":
            advance()
            loadAsync = true

        default:
            // unknown command line option
            advance()
    }
}

// get application details

var app: NSRunningApplication? = nil
if pid == -1 {
    app = NSWorkspace.shared().menuBarOwningApplication
}
else {
    app = NSRunningApplication(processIdentifier: pid)
}

guard let app = app,
        let appName = app.localizedName,
        let appUrl = app.bundleURL
        else {
            Alfred.quit("Unable to get app info")
        }
let appPath  = appUrl.path
let axApp = AXUIElementCreateApplication(app.processIdentifier)

// try to get a reference to the menu bar

var menuBarValue: CFTypeRef? = nil
let result = AXUIElementCopyAttributeValue(axApp, kAXMenuBarAttribute as CFString, &menuBarValue)
switch result {

    case .success:
        break

    case .apiDisabled:
        Alfred.quit("Assistive applications are not enabled in System Preferences.", "Is accessibility enabled for Alfred?")    

    case .noValue:
        Alfred.quit("No menu bar", "\(appName) does not have a native menu bar")

    default:
        Alfred.quit("Could not get menu bar", "An error occured \(result.rawValue)")    
}

// try to get all menu items

let menuBar = menuBarValue as! AXUIElement

// if we need to click a menu path
// then do that
if let clickIndices = clickIndices, clickIndices.count > 0 {
    clickMenu(menu: menuBar, pathIndices: clickIndices, currentIndex: 0)
    MenuItemCache.invalidate(app: app.bundleIdentifier!)
    exit(0)
}

var menuItems = [MenuItem]()
let a = Alfred()

if cachingEnabled, let items = MenuItemCache.load(app: app.bundleIdentifier!, timeout: cacheTimeout) {
    // caching enabled and we were able to load information
    menuItems = items
}
else {
    if loadAsync {
        menuItems = AsyncMenu.load (
            menuBar: menuBar, 
            maxDepth: maxDepth, 
            maxChildren: maxChildren
        )
    }
    else {
        getMenuItems(
            forElement: menuBar, 
            menuItems: &menuItems, 
            maxDepth: maxDepth, 
            maxChildren: maxChildren
        )
    }
    if cachingEnabled {
        MenuItemCache.save(app: app.bundleIdentifier!, items: menuItems)
    }
}

// filter menu items and render result

// func r(_ menu: MenuItem) -> () {
func render(_ menu: MenuItem) -> () {
    let apple = menu.appleMenuItem
    a.add(
        uid: learning ? "\(appName)>\(menu.uid)" : nil, 
        title: (menu.shortcut != nil ? "\(menu.title) - \(menu.shortcut!)" : menu.title), 
        subtitle: menu.subtitle, 
        arg: menu.arg, 
        iconPath: apple ? "apple-icon.png" : appPath,
        iconType: apple ? nil : "fileicon"
    )
}
let r = render // prevent swiftc compiler segfault

if !query.isEmpty {

    let search = TextSearch(term: query.lowercased())
    let rankedMenuItems: [(MenuItem, Int)] = 
        menuItems
        .map { (menu: MenuItem) -> (MenuItem, Int) in
            // finds the first ranked path component
            // if we have File -> New Tab
            // and we enter "file", we must match "file"
            // we enter "nt", we must match "new tab"
            // work our way starting from the leaf menu path
            // and upwards until a ranked match is found

            // for the last item alone, do a fuzzy match 
            // along with normal ranked search
            var i = menu.path.count - 1
            let rank = search.rank(for: menu.path[i].lowercased())
            if rank == 100 {
                return (menu, rank)
            }
            let fuzzyScore = menu.fuzzyIndex.contains(search.term) ? 50 : 0
            let score = max(fuzzyScore, rank)
            if score > 0 {
                return (menu, score)
            }

            // normally rank the other path components
            i -= 1
            while i >= 0 {
                let r = search.rank(for: menu.path[i].lowercased())
                if r > 0 {
                    return (menu, r)
                }
                i -= 1
            }

            // no matches at all
            return (menu, 0)
        }
        .sorted(by: { $0.0.1 > $0.1.1 })

    
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
    if i == 0 {
        a.add(title: "No menu items")
    }

}
else if reorderAppleMenuToLast, menuItems.count > 0 {
    // rearrange so that Apple menu items are last
    // do not use filter as its slow with unnecessary copying 
    // instead we find
    // the index of menu items which is not a apple menu
    // then display all items from that range
    // followed by all items in the starting range

    // yes this is more verbose code, but faster
    // 0..<j will be apple menu items
    // j..<end will be app menu items

    let end = menuItems.endIndex
    if let i = menuItems.index(where: { $0.appleMenuItem }) {
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
        menuItems[0..<j].forEach { r($0) }
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
    if menuItems.isEmpty {
        a.add(title: "No menu items")
    }
    else {
        menuItems.forEach { r($0) }
    }
}

print(a.output())
