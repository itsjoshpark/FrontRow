# Release notes

Release notes are kept with [Changie](https://changie.dev) (`brew install changie`).
Every user-facing change adds a fragment in the same pull request:

```sh
changie new                                   # prompts for the kind and the text
changie new --kind Fixed --body "Something that was broken"
```

Kinds are `New`, `Changed`, `Fixed` and `Updated`. With the release type `auto`,
`New` bumps the minor version and the others bump the patch. Changes users don't
notice (CI, refactors, docs) get no fragment.

The release workflow batches `unreleased/` into `<version>.md`, regenerates
`CHANGELOG.md`, and stamps the version into the project. The file becomes the
GitHub release body as written, and `scripts/render-notes.sh` converts it to the
HTML fragment embedded in the appcast's `<description>` CDATA and shown in
Sparkle's update dialog. Each fragment becomes one line, in the format below, so
write for users rather than summarizing commits:

```markdown
- New: Something people asked for
- Fixed: Something that was broken
```

For a free-text note above the list (e.g. `**Note**: Anything worth calling out
before updating.`), write `unreleased/header.md` before releasing. The release
consumes it.

Lists, paragraphs, bold, italic, links, tables, task lists, and strikethrough
all work. Two things are rejected, because each would reach one destination and
not the other:

- **HTML tags**. GitHub renders them, but the appcast conversion drops them, so
  the release page and Sparkle's dialog would disagree.
- **Code blocks**, including a line indented four spaces. The appcast is
  indented to match, and that indentation would show inside a `<pre>`.

Footnotes are the one GitHub construct left unsupported, and render as literal
`[^1]` markers.

Rendering uses [cmark-gfm](https://github.com/github/cmark-gfm), GitHub's own
Markdown implementation, so Sparkle shows what the release page shows. To run
the script tests locally: `brew install cmark-gfm`.

The `<version>.md` files are the archive of what shipped in each release. Notes
up to 2.11.0 were written as HTML fragments and have been converted; the appcast
entries already published keep the HTML they shipped with.
