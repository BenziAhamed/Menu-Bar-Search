//
//  Cache.swift
//  Menu
//
//  Created by Benzi on 23/04/17.
//  Copyright © 2017 Benzi Ahamed. All rights reserved.
//

import Foundation
import SwiftProtobuf

struct CacheControl: CustomStringConvertible {
    let appBundleId: String
    let control: MenuItemCache
    
    var description: String {
        return "app:\(appBundleId) created:\(control.created) timeout:\(control.timeout)"
    }
}

enum CacheType: String {
    case cache
    case menus
}

// cache
enum Cache {
    static func getURL(_ app: String, _ type: CacheType) -> URL {
        let base = app
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return URL(fileURLWithPath: Alfred.cache(path: "\(base).\(type.rawValue)"))
    }
    
    static func save(app: String, items: [MenuItem], lifetime: Double) {
        var control = MenuItemCache()
        control.created = Date().timeIntervalSince1970
        control.timeout = control.created + lifetime
        var list = MenuItemList()
        list.items = items
        save(control, getURL(app, .cache))
        save(list, getURL(app, .menus))
    }
    
    static func save(_ message: Message, _ url: URL) {
        guard let d = try? message.serializedData() else { return }
        do {
            try d.write(to: url)
        } catch {}
    }
    
    static func load(app: String, settingsModifiedInterval: Double? = nil) -> [MenuItem]? {
        let controlURL = getURL(app, .cache)
        guard let controlData = try? Data(contentsOf: controlURL),
              let control = try? MenuItemCache(serializedData: controlData)
        else { return nil }
        
        // settings was updated since we last created the cache
        if let interval = settingsModifiedInterval, control.created <= interval {
            return nil
        }
        
        let dt = Date().timeIntervalSince1970 - control.timeout
        if dt >= 1 {
            // too stale data, invalidate for sure
            return nil
        }
        
        let url = getURL(app, .menus)
        guard let d = try? Data(contentsOf: url),
              let list = try? MenuItemList(serializedData: d) else { return nil }
        
        // if we timedout within 1 second
        // slide the timeout window forward
        // this allows us to reuse the cache if we are close
        if dt < 1 {
            var control = control
            control.timeout += 3
            save(control, controlURL)
        }
        
        return list.items
    }
    
    static func invalidate(app: String) {
        try? FileManager.default.removeItem(at: getURL(app, .cache))
    }
    
    static func getCachedMenuControls() -> [CacheControl] {
        var controls = [CacheControl]()
        let fm = FileManager.default
        let cachePath = Alfred.cache()
        guard let files = try? fm.contentsOfDirectory(atPath: cachePath) else {
            return controls
        }
        for file in files where file.hasSuffix(".cache") {
            let bundleID = String(file.dropLast(6))
            guard let controlData = try? Data(contentsOf: getURL(bundleID, .cache)) else {
                continue
            }
            guard let control = try? MenuItemCache(serializedData: controlData)
            else {
                continue
            }
            controls.append(.init(
                appBundleId: bundleID,
                control: control
            ))
        }
        return controls
    }
}
