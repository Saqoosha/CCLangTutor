import Testing
@testable import CCLangTutor

@Suite
struct PromptFilterTests {

    // MARK: - URL Tests

    @Test
    func filtersHttpsURL() {
        let input = "Check https://example.com/path please"
        let result = PromptFilter.filter(input)
        #expect(result == "Check [URL] please")
    }

    @Test
    func filtersHttpURL() {
        let input = "Visit http://example.com"
        let result = PromptFilter.filter(input)
        #expect(result == "Visit [URL]")
    }

    @Test
    func filtersWwwURL() {
        let input = "Go to www.example.com/page"
        let result = PromptFilter.filter(input)
        #expect(result == "Go to [URL]")
    }

    @Test
    func filtersMarkdownLink() {
        let input = "See [documentation](https://docs.example.com) here"
        let result = PromptFilter.filter(input)
        #expect(result == "See [documentation]([URL]) here")
    }

    @Test
    func filtersMultipleURLs() {
        let input = "Visit https://one.com and https://two.com"
        let result = PromptFilter.filter(input)
        #expect(result == "Visit [URL] and [URL]")
    }

    // MARK: - File Path Tests

    @Test
    func filtersAbsolutePath() {
        let input = "Edit /Users/hiko/file.swift please"
        let result = PromptFilter.filter(input)
        #expect(result == "Edit [path] please")
    }

    @Test
    func filtersHomePath() {
        let input = "Check /home/user/project/src/main.ts"
        let result = PromptFilter.filter(input)
        #expect(result == "Check [path]")
    }

    @Test
    func filtersRelativePath() {
        let input = "Look at ./src/main.ts"
        let result = PromptFilter.filter(input)
        #expect(result == "Look at [path]")
    }

    @Test
    func filtersParentPath() {
        let input = "Check ../config/settings.json"
        let result = PromptFilter.filter(input)
        #expect(result == "Check [path]")
    }

    @Test
    func filtersLibraryPath() {
        // Paths with spaces are cut at the space boundary
        let input = "Open /Library/Preferences/app.plist"
        let result = PromptFilter.filter(input)
        #expect(result == "Open [path]")
    }

    // MARK: - Mixed Content

    @Test
    func filtersMixedContent() {
        let input = "Open https://api.com and edit /Users/x/y.ts"
        let result = PromptFilter.filter(input)
        #expect(result == "Open [URL] and edit [path]")
    }

    @Test
    func filtersComplexMixedContent() {
        // Note: comma directly after URL becomes part of the replacement
        let input = "Fetch from https://api.example.com/v1 then save to ./output/data.json and log to /var/log/app.log"
        let result = PromptFilter.filter(input)
        #expect(result == "Fetch from [URL] then save to [path] and log to [path]")
    }

    // MARK: - No Filtering Needed

    @Test
    func preservesNormalText() {
        let input = "Fix the grammar mistake please"
        let result = PromptFilter.filter(input)
        #expect(result == "Fix the grammar mistake please")
    }

    @Test
    func preservesNonPathSlashes() {
        let input = "Use and/or logic here"
        let result = PromptFilter.filter(input)
        #expect(result == "Use and/or logic here")
    }

    @Test
    func preservesCodeSnippets() {
        let input = "Use `const x = 1 / 2` for division"
        let result = PromptFilter.filter(input)
        #expect(result == "Use `const x = 1 / 2` for division")
    }

    @Test
    func preservesEmptyString() {
        let input = ""
        let result = PromptFilter.filter(input)
        #expect(result == "")
    }

    // MARK: - Edge Cases

    @Test
    func filtersURLInParentheses() {
        let input = "Check this (https://example.com) link"
        let result = PromptFilter.filter(input)
        #expect(result == "Check this ([URL]) link")
    }

    @Test
    func filtersPathInQuotes() {
        let input = "Open \"/Users/test/file.txt\" please"
        let result = PromptFilter.filter(input)
        #expect(result == "Open \"[path]\" please")
    }
}
