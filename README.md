# Menu-Bar-Search

![logo](menu-search.png)

Search through menu options for front-most application - an Alfred Workflow

> Based on the implementation of [ctwise's Menu Bar Search](https://www.alfredforum.com/topic/1993-menu-search/).

## Downloads

- [Download latest](https://github.com/BenziAhamed/Menu-Bar-Search/raw/master/Menu%20Bar%20Search.alfredworkflow)
- [Download v1.8](https://github.com/BenziAhamed/Menu-Bar-Search/raw/v1.8/Menu%20Bar%20Search.alfredworkflow)

### Running on macOS Catalina and beyond (for v1.8)
> If you face issues from Catalina or beyond, in relation to not being able to run the workflow due to security issues (e.g. malicious software checks),
> have a look at https://github.com/BenziAhamed/Menu-Bar-Search/issues/4 for possible workarounds.
> 
> I am aware of this outstanding issue and will fix it.

## Usage

Type `m` in Alfred to list menu bar items for front most application
You can filter menu items by name, or do a fuzzy search.

E.g

- `m new tab` will match the menu item **New Tab**
- `m cw` will match the menu item **Close Window**

## Releases

Download previous versions from [Github releases](https://github.com/BenziAhamed/Menu-Bar-Search/releases).

## Change log

- 1.0 - Initial Release
- 1.1 - Added Fuzzy Text Matching for Menus

  If you have a menu item `New Tab`, then typing `m nt` in Alfred will match `New Tab`, since `n` and `t` matches the first letters of the menu text.

- 1.1.1 - Changed run behaviour to terminate previous script, this makes the experience slightly more faster
- 1.2 - Completely native menu clicking, removed reliance on AppleScript
  - 1.2.1 - Performance improvements when generating menus using direct JSON encoding
  - 1.2.2 - More performance improvements while filtering menu items
- 1.3 - Added `-async` flag to allow threaded scanning and populating of menus
- 1.4 - Added `-cache` setting to enable menu result caching and also set a timeout for cache invalidation
  - 1.4.1 - Invalidate cache (if present) after actioning a menu press
  - 1.4.2 - Slide the cache invalidation window forward in case we get invalidated by a near miss
  - 1.4.3 - Speed improvements to caching, text search and fuzzy matching
  - 1.4.4 - Added `-no-apple-menu` flag that will skip the apple menu items
  - 1.4.5 - Tuned fuzzy matcher, allows non-continuous anchor token search
- 1.5 - Faster caching using protocol buffers
  - 1.5.1 - Reduced file creation for cache storage
  - 1.5.2 - Better support for command line apps that create menu bar owning applications
  - 1.5.3 - Protocol buffer everything - microscopic speed improvements, but hey...
  - 1.5.4 - Added various environment variables to fine tune menu listings
  - 1.5.5 - Tweaked ranking of search results for better menu listings
- 1.6 - Added per app customization via Settings.txt configuration file
- 1.7 - Universal build for M1 and Intel
- 1.8 - Fixed the universal build
- 1.9 - changed to user configuration, and signed executable (exported using Alfred 5)
