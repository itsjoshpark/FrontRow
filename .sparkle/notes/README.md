# Release notes

Write the next release's notes in `next.html`. There is no version in the name,
so nothing has to be decided in advance — the release workflow works out the
version from the `patch`/`minor`/`major` choice, renames `next.html` to
`<version>.html`, and drops a fresh copy of `TEMPLATE.html` in its place.

The workflow refuses to release while `next.html` is still the unedited
template.

The contents are embedded directly into the appcast's `<description>` CDATA and
shown in Sparkle's update dialog, so write for users rather than summarizing
commits. The same file becomes the GitHub release body.

Keep it to an HTML fragment — no `<html>` or `<body>` wrapper, and no `]]>`
anywhere, which would terminate the CDATA section (the workflow rejects it):

```html
      <ul>
      <li>Added: Something people asked for</li>
      <li>Fixed: Something that was broken</li>
      </ul>
```

The older `<version>.html` files are the archive of what shipped in each
release.
