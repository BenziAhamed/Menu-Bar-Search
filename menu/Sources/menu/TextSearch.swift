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
        if term.isEmpty || isEmpty { return 0 }
        
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
                        return 300 + term.count - penalty
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
        if term.isEmpty || isEmpty { return 0 }
        
        guard let r = range(of: term) else { return 0 }
        if r.lowerBound == self.startIndex { return 500 }
        
        let dist = self[startIndex ..< r.lowerBound].count
        let letters = CharacterSet.letters
        for s in String(self[index(before: r.lowerBound)]).unicodeScalars {
            if letters.contains(s) { return 100 - dist }
        }
        return 250 - dist
    }
}


extension String {
    
    var anchorTerm: String {
        var result = ""
        var consume = true
        for c in self {
            if consume {
                if !c.isWhitespace {
                    result.append(c)
                    consume = false
                }
            } else {
                if c.isWhitespace {
                    consume = true
                }
            }
        }
        return result
    }
    
    func fastMatch(_ query: String) -> (matched: Bool, score: Int) {
        if query.count > self.count {
            return (false, 0)
        }
        
        let anchorTerm = self.anchorTerm
        if anchorTerm.hasPrefix(query) {
            let unmatched = (anchorTerm.count - query.count)
            return (true, 8192 - unmatched * 2)
        }

        var unmatchedPrefixCount = 0
        var currentMatchingRun = 0
        var maxRun = 0
        var gaps = 0
        var runBreakPenalty = 1
        var queryIndex = query.startIndex
        var lastIndex = query.index(before: query.endIndex)
        var lastMatchIndex = -1
        for (pos, c) in self.enumerated() {
            if c == query[queryIndex] {
                if pos - lastMatchIndex == 1 || queryIndex == query.startIndex {
                    currentMatchingRun += 1
                    maxRun = max(maxRun, currentMatchingRun)
                } else {
                    currentMatchingRun = 0
                    runBreakPenalty += 1
                }
                lastMatchIndex = pos
                if queryIndex == lastIndex {
                    let unmatchedSuffixCount = count - pos - 1
                    let score = (maxRun * 100) - (gaps * 1) - (unmatchedPrefixCount * 7) - (unmatchedSuffixCount * 1)
                    return (true, score)
                }
                queryIndex = query.index(after: queryIndex)
            } else {
                if !c.isWhitespace {
                    if queryIndex == query.startIndex {
                        unmatchedPrefixCount += 1
                    } else {
                        gaps += runBreakPenalty
                    }
                }
            }
        }
        return (false, 0)
    }
}
