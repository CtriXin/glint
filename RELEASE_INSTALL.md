# Install CtriTerm

This package contains the Apple-notarized CtriTerm app for Apple Silicon Macs.

## Requirements

- macOS 14 or later
- Apple Silicon (M-series) Mac

## Install

1. Download the release ZIP and its `.sha256` checksum file.
2. Optionally verify the download:

   ```bash
   shasum -a 256 -c CtriTerm-<version>-macos-arm64-notarized.zip.sha256
   ```

3. Double-click the ZIP, then drag `CtriTerm.app` to `/Applications`.
4. Open CtriTerm from Applications or Spotlight.

The app is signed with Developer ID and notarized by Apple. It can coexist with
upstream Glint because the bundle identifiers differ.

## Updating

Download a newer CtriTerm release and replace `/Applications/CtriTerm.app`.
CtriTerm deliberately does not use an automatic update feed.

## Support and Legal Notices

This is a CtriTerm distribution maintained in the CtriXin Glint fork. It is not
a release from the upstream Glint project. See `THIRD_PARTY_NOTICES.md` and the
`LICENSES/` directory for required upstream notices and licenses.
