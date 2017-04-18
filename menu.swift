// menu.swift - renders menu bar items as Alfred results
// (c) Benzi Ahamed, 2017

import Foundation
import Cocoa

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
    var shortcut: String? = nil
    
    var uid: String {
        return path.joined(separator: ">")
    }

    var appleMenuItem: Bool {
        return path[0] == "Apple" 
    }

    var arg: String {
        var i = path.endIndex - 1
        var a = "menu item \"\(path[i])\""
        i -= 1
        while i >= 0 {
            let current = path[i]
            if i > 0 {
                // http://stackoverflow.com/questions/12121803/applescript-to-open-open-recent-file
                a.append(" of menu \"\(current)\" of menu item \"\(current)\"")
            }
            else {
                a.append(" of menu \"\(current)\"")   
            }
            i -= 1
        }
        a.append(" of menu bar item \"\(path[0])\" of menu bar 1")
        return a
    }
    
    var subtitle: String {
        var p = path
        p.removeLast()
        return p.joined(separator: " > ")
    }
    
    var title: String {
        return path.last!
    }
    
    func contains(filter: String) -> Bool {
        for i in path.indices.reversed() {
            if path[i].lowercased().contains(filter) {
                return true
            }
        }
        return false
    }
}


func getMenuItems(
    forElement element: AXUIElement,
    bundleIdentifier: String,
    menuItems: inout [MenuItem],
    path: [String] = [],
    depth: Int = 0,
    maxDepth: Int = 10,
    maxChildren: Int = 20
    ) {
    guard depth < maxDepth else { return }
    guard let children = getAttribute(element: element, name: kAXChildrenAttribute) as? [AXUIElement], children.count > 0 else { return }
    var processedChildrenCount = 0
    for child in children {
        guard let enabled = getAttribute(element: child, name: kAXEnabledAttribute) as? Bool, enabled else { continue }
        guard let name = getAttribute(element: child, name: kAXTitleAttribute) as? String else { continue }
        guard !name.isEmpty else { continue }
        guard let children = getAttribute(element: child, name: kAXChildrenAttribute) as? [AXUIElement] else { continue }
        
        if children.count == 1 {
            // sub-menu item, scan children
            getMenuItems(
                forElement: children[0],
                bundleIdentifier: bundleIdentifier,
                menuItems: &menuItems,
                path: path + [name],
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

            menuItems.append(MenuItem(path: path + [name], shortcut: getShortcut(cmd, modifiers, virtualKey)))
        }
        
        processedChildrenCount += 1
        if processedChildrenCount > maxChildren {
            break
        }
    }
}



// process command line args
// -query ""
// -pid ""
var query: String = ""
var pid: Int32 = -1

var i = 1 // skip name of program
var current: String? {
    return i < CommandLine.arguments.count ? CommandLine.arguments[i] : nil
}
func advance() {
    i += 1
}
while let arg = current {
    switch arg {
        case "-pid":
            advance()
            if let arg = current, let value = Int32(arg) {
                pid = value
                advance()
            }
            else {
                Alfred.quit("Expected value after -pid arg")
            }
        case "-query":
            advance()
            if let arg = current {
                advance()
                query = arg.lowercased()
            }
        default:
            // unknown command line option
            advance()
    }
}


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

var menuBarValue: CFTypeRef? = nil
let result = AXUIElementCopyAttributeValue(axApp, kAXMenuBarAttribute as CFString, &menuBarValue)
switch result {
    case .apiDisabled:
        Alfred.quit("Assistive applications are not enabled in System Preferences.", "Is accessibility enabled for Alfred?")    
    case .noValue:
        Alfred.quit("No menu bar", "\(appName) does not have a native menu bar")
    case .success:
        break
    default:
        Alfred.quit("Could not get menu bar", "An error occured \(result.rawValue)")    
}

let menuBar = menuBarValue as! AXUIElement

var menuItems = [MenuItem]()
getMenuItems(forElement: menuBar, bundleIdentifier: app.bundleIdentifier!, menuItems: &menuItems)

let a = Alfred()

if !query.isEmpty {
    menuItems = menuItems.filter { $0.contains(filter: query) }
}
else {
    // rearrange so that Apple menu items are last
    menuItems = menuItems.filter { $0.path[0] != "Apple" } + menuItems.filter { $0.path[0] == "Apple" }
}
if menuItems.isEmpty {
    a.add(title: "No menu items")
}
else {
    menuItems.forEach { 
        let apple = $0.appleMenuItem
        a.add(
            uid: "\(appName)>\($0.uid)", 
            title: $0.shortcut != nil ? "\($0.title) - \($0.shortcut!)" : $0.title, 
            subtitle: $0.subtitle, 
            arg: $0.arg, 
            iconPath: apple ? "apple-icon.png" : appPath,
            iconType: apple ? nil : "fileicon"
        )
    }
}

print(a.output())



