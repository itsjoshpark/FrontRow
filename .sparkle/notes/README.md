# Release notes

One file per release, named for the marketing version: `2.11.0.html`.

The release workflow fails early if the file for the version being released is
missing, so write it before triggering a release.

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
