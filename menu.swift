// menu.swift - renders menu bar items as Alfred results
// (c) Benzi Ahamed, 2017

import Foundation
import Cocoa

struct TextSearch {
    
    let term: String
    var regex: NSRegularExpression?
    
    init(term: String) {
        self.term = term
        if term.characters.count <= 1 {
            regex = nil
        }
        else {
            // given a search term ab
            // we want to match all text with words starting a and b one after another
            // ... a.* b.* ...
            // the words may appear anywhere within the search text
            let pattern = term
            .characters
            .map { "[\($0)][^\\s]*" } // match a word with starting letter of interest
            .joined(separator: "\\s")
            let s = term.characters.first!
            // start with first letter as long as its at a word boundary
            let final = "^[^\(s)]*\\b\(pattern).*$"
            regex = try? NSRegularExpression(pattern: final, options: [])
        }
    }
    

    // returns a ranked for a given item, based on the text specified
    // text ranking is as follows:
    // if text starts with the term, rank = 100 (best match)
    // if text succeeds with fuzzy match, rank = 20
    // if text contains term, rank = 10
    // else rank = 0
    func rank<T>(item: T, for text: String) -> (T, Int) {
        
        // text starts with term, best match
        if text.hasPrefix(term) {
            return (item, 100)
        }
        
        // fuzzy search
        if term.characters.count > 1, text.characters.count >= term.characters.count, let regex = regex {
            if regex.numberOfMatches(
                in: text,
                options: [],
                range: .init(location: 0, length: text.characters.count)
                ) > 0 {
                return (item, 20)
            }
        }
        
        // contains text someplace
        if text.contains(term) {
            return (item, 10)
        }
        
        // no match
        return (item, 0)
    }
    
}



class Alfred {
    
    let results = NSMutableArray()
    
    func add(uid: String? = nil, type: String? = nil, title: String? = nil, subtitle: String? = nil, arg: String? = nil, autocomplete: String? = nil, iconPath: String? = nil, iconType: String? = nil) {
        
        let s = NSMutableDictionary()
        
        func add(_ key :String, _ value: Any?, to dict: NSMutableDictionary) {
            guard let value = value else { return }
            dict.setValue(value, forKey: key)
        }
        
        add("uid", uid, to: s)
        add("type", type, to: s)
        add("title", title, to: s)
        add("subtitle", subtitle, to: s)
        add("arg", arg, to: s)
        add("autocomplete", autocomplete, to: s)

        if arg == nil {
            add("valid", false, to: s)
        }

        if iconType != nil || iconPath != nil {
            let icon = NSMutableDictionary()
            add("type", iconType, to: icon)
            add("path", iconPath, to: icon)
            s.setValue(icon, forKey: "icon")
        }
        guard s.count > 0 else { return }
        results.add(s)
    }
    
    func output() -> String {
        let dict = NSMutableDictionary()
        dict.setValue(results, forKey: "items")
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: JSONSerialization.WritingOptions.prettyPrinted),
            let output = String.init(data: data, encoding: String.Encoding.utf8) else {
                return "{\"items\": []}"
        }
        return output
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

func getAttribute(element: AXUIElement, name: String) -> CFTypeRef? {
    var value: CFTypeRef? = nil
    AXUIElementCopyAttributeValue(element, name as CFString, &value)
    return value
}

struct MenuItem {

    var path: [String]
    var pathIndices: String
    var shortcut: String? = nil
    
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


func clickMenu(menu element: AXUIElement, pathIndices: [Int], currentIndex: Int) {
    guard let menuBarItems = getAttribute(element: element, name: kAXChildrenAttribute) as? [AXUIElement], menuBarItems.count > 0 else { return }
    let itemIndex = pathIndices[currentIndex]
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
                depth: depth + 1
            )
        }
        else {
            // not a sub menu, if we have a path to this item, print it
            // print(path, "::", name)
            let cmd = getAttribute(element: child, name: kAXMenuItemCmdCharAttribute) as? String
            var modifiers: Int = 0
            var virtualKey: Int = 0
            if let m = getAttribute(element: child, name: kAXMenuItemCmdModifiersAttribute) {
                CFNumberGetValue(m as! CFNumber, CFNumberType.longType, &modifiers)
            }
            if let v = getAttribute(element: child, name: kAXMenuItemCmdVirtualKeyAttribute) {
                CFNumberGetValue(v as! CFNumber, CFNumberType.longType, &virtualKey)
            }
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



// process command line args
// every argument is optional
// [-query <filter>] - filter menu listing based on filter
// [-pid <id>] - target app with specified pid, if none, menubar owning app is detected
// [-max-depth <depth:10>]  - max traversal depth of app menu
// [-max-children <count:20>] -  max set of child menu items to process under parent menu
// -reorder-apple-menu (true|false:true) - by default, orders Apple menu items to the last
// -learning  (true|false:true)
// -click <json_index_path_to_menu_item> - clicks the menu path for the given pid app

var query = ""
var pid: Int32 = -1
var maxDepth = 10
var maxChildren = 20
var reorderAppleMenuToLast = true
var learning = true
var clickIndices: [Int]? = nil

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

        case "-query":
            advance()
            if let arg = current {
                advance()
                query = arg.lowercased()
            }

        case "-max-depth":
            advance()
            maxDepth = parse(createInt, "Expected integer after -max-depth")

        case "-max-children":
            advance()
            maxChildren = parse(createInt, "Expected integer after -max-children")

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
if let clickIndices = clickIndices {
    clickMenu(menu: menuBar, pathIndices: clickIndices, currentIndex: 0)
    exit(0)
}


var menuItems = [MenuItem]()
getMenuItems(
    forElement: menuBar, 
    menuItems: &menuItems, 
    maxDepth: maxDepth, 
    maxChildren: maxChildren
    )


// filter menu items and render result

let a = Alfred()

if !query.isEmpty {

    let search = TextSearch(term: query.lowercased())
    
    menuItems = menuItems
        .map { (menu: MenuItem) -> (MenuItem, Int) in
            // finds the first ranked path component
            // if we have File -> New Tab
            // and we enter "file", we must match "file"
            // we enter "nt", we must match "new tab"
            // work our way starting from the leaf menu path
            // and upwards until a ranked match is found
            for i in menu.path.indices.reversed() {
                let r = search.rank(item: menu, for: menu.path[i].lowercased())
                if r.1 > 0 {
                    return r
                }
            }
            return (menu, 0)
        }
        // filter and sort out ranked items
        // higher rank means better match
        .filter { $0.1 > 0 }
        .sorted(by: { $0.0.1 > $0.1.1 })
        .map { $0.0 }
}
else if reorderAppleMenuToLast {
    // rearrange so that Apple menu items are last
    menuItems = menuItems.filter { !$0.appleMenuItem } + menuItems.filter { $0.appleMenuItem }
}


if menuItems.isEmpty {
    a.add(title: "No menu items")
}
else {
    menuItems.forEach { 
        let apple = $0.appleMenuItem
        a.add(
            uid: learning ? "\(appName)>\($0.uid)" : nil, 
            title: ($0.shortcut != nil ? "\($0.title) - \($0.shortcut!)" : $0.title), 
            subtitle: $0.subtitle, 
            arg: $0.arg, 
            iconPath: apple ? "apple-icon.png" : appPath,
            iconType: apple ? nil : "fileicon"
        )
    }
}

print(a.output())

