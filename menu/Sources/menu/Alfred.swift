//
//  Alfred.swift
//  Menu
//
//  Created by Benzi on 23/04/17.
//  Copyright © 2017 Benzi Ahamed. All rights reserved.
//

import Foundation

class Alfred {
    
    static func preparePaths() {
        let fm = FileManager.default
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
    
    var results = AlfredResultList()
    
    func add(_ item: AlfredResultItem) {
        results.items.append(item)
    }
    
    var resultsJson: String {
        return (try? results.jsonString()) ?? "{\"items\":[]}"
    }
    
    static func quit(_ title: String, _ subtitle: String? = nil) -> Never {
        let a = Alfred()
        a.add(.with { $0.title = title; $0.subtitle = subtitle ?? "" })
        print(a.resultsJson)
        exit(0)
    }
    
}
