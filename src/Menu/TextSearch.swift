//
//  TextSearch.swift
//  Menu
//
//  Created by Benzi on 23/04/17.
//  Copyright © 2017 Benzi Ahamed. All rights reserved.
//

import Foundation

extension String {
    
    // fuzzy match a term against a string
    // matches alphanumerics against input term unicode scalars
    // e.g. Arabic (Windows 1)
    // will match a, w, 1, aw, w1, aw1
    // also match a1
    // but not a1
    // for "1 way street"
    // 1ws > 1w > 1 > ws > w > s
    // complexity: O(n) where n = characters in self
    func fuzzyMatch(term: String) -> Int {
        
        if term.isEmpty || isEmpty { return  0 }
        
        let alphaNum = CharacterSet.alphanumerics
        let whitespace = CharacterSet.whitespaces
        
        // location in the term string
        let termScalars = term.unicodeScalars
        var index = termScalars.startIndex
        let end = termScalars.endIndex
        
        var waitingForSpace = false
        var penalty = 0
        for c in self.unicodeScalars {
            // advance through all characters in self
            // when we hit a anchor character, match
            // against the term and if it matches
            if alphaNum.contains(c), !waitingForSpace {
                // if we hit a anchor, check if it matches
                // current term scalar
                if termScalars[index] == c {
                    index = termScalars.index(after: index)
                    if index == end {
                        return 300 + term.characters.count - penalty
                    }
                }
                else {
                    penalty += 2 // how far away did we start off matching
                }
                waitingForSpace = true
            }
            else if waitingForSpace, whitespace.contains(c) {
                waitingForSpace = false
            }
        }
        
        
        return 0
    }
}

extension String {
    
    // if word starts with term 500
    // if term is inside self
    // if at a word boundary 150 - distance
    // else 100 - distance
    func textMatch(term: String) -> Int {
        
        if term.isEmpty || isEmpty { return  0 }
        
        guard let r = range(of: term) else { return 0 }
        if r.lowerBound == self.startIndex { return 500 }
        
        let dist = self[startIndex..<r.lowerBound].characters.count
        let letters = CharacterSet.letters
        for s in String(self[index(before: r.lowerBound)]).unicodeScalars {
            if letters.contains(s) { return 100 - dist }
        }
        return 250 - dist
    }
    
}

