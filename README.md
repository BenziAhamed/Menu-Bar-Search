# Menu-Bar-Search

![logo](menu-search.png)

Search through menu options for front-most application - Alfred Workflow

This is a slightly faster implementation of [ctwise's Menu Bar Search](https://www.alfredforum.com/topic/1993-menu-search/).

[Download](https://github.com/BenziAhamed/Menu-Bar-Search/raw/master/Menu%20Bar%20Search.alfredworkflow)


## Change log
- 1.0 - Initial Release
- 1.1 - Added Fuzzy Text Matching for Menus

  If you have a menu item `New Tab`, then typing `m nt` in Alfred will match `New Tab`, since `n` and `t` matches the first letters of the menu text.

- 1.1.1 - Changed run behaviour to terminate previous script, this makes the experience slightly more faster
- 1.2 - Completely native menu clicking, removed reliance on AppleScript
