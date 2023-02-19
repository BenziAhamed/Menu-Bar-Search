//
//  TextSearch.swift
//  Menu
//
//  Created by Benzi on 23/04/17.
//  Copyright © 2017 Benzi Ahamed. All rights reserved.
//

import Foundation

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
        let lastIndex = query.index(before: query.endIndex)
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
