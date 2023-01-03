//
//  MenuItem.Alfred.swift
//  Menu
//
//  Created by Benzi on 24/04/17.
//  Copyright © 2017 Benzi Ahamed. All rights reserved.
//

import Foundation

extension MenuItem {
    var arg: String {
        return pathIndices
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
