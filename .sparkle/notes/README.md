# Release notes

Write the next release's notes in `next.md`. There is no version in the name,
so nothing has to be decided in advance — the release workflow works out the
version from the `patch`/`minor`/`major` choice, renames `next.md` to
`<version>.md`, and drops a fresh copy of `TEMPLATE.md` in its place.

The workflow refuses to release while `next.md` is still the unedited template.

The file becomes the GitHub release body verbatim, and `scripts/render-notes.sh`
converts it to the HTML fragment embedded in the appcast's `<description>` CDATA
and shown in Sparkle's update dialog. So write for users rather than summarizing
commits:

```markdown
- New: Something people asked for
- Fixed: Something that was broken

**Note**: Anything worth calling out before updating.
```

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

The older `<version>.md` files are the archive of what shipped in each release.
Notes up to 2.11.0 were written as HTML fragments and have been converted; the
appcast entries already published keep the HTML they shipped with.
