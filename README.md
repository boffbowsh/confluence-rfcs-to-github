# Confluence RFCs -> Github importer

Takes RFCs from a Confluence export and adds them to a Github repo.

Handles:

- Emoji :wink:
- Page comments
- Inline comments
- Comment threads
- Creating, merging and closing PRs
- Document history
- Resolving usernames

## How to use

1. Obtain an export from Confluence.
      1. Space tools -> Content tools -> Export -> XML -> Custom export
      2. Include comments
      3. Deselect all
      4. Tick the "Request for comments" index page
2. Extract the export to the root of this directory. It should contain an `entities.xml`
3. Add github credentials to `~/.netrc`. The password should be a personal access token:

        machine api.github.com
        login foobar
        password 98d5629ecbb5be56c24c7890692d9426a7b46ff4

4. Run `bundle install`
5. Run the tool, configuring the target repository and author name as environment variables:
```
export REPOSITORY=https://github.com/alphagov/govuk-rfcs.git
export AUTHOR='Wikibot <wikibot@example.com>'
./import_confluence
```

It should take about 10 minutes to run.

## Todo

- Handle images. Github supports uploading attachments to Issues and Comments, but not using the API.
- Extract the Confluence export parsing doohickey into a gem. It could be useful to others.
- Tests :joy:
- Set dates on commits

