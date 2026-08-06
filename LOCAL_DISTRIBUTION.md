# Local Distribution

This fork installs alongside upstream Glint as **CtriTerm**.

## Identity and update boundary

- Bundle ID: `com.ctrixin.glint`
- Debug Bundle ID: `com.ctrixin.glint.dev`
- URL scheme: `ctrixin-glint://`
- Application Support: `~/Library/Application Support/CtriXin-Glint/`
- Upstream Sparkle updates are intentionally disabled. An upstream appcast can
  otherwise replace this separately signed app with a different binary.

The UI and behavioral commits are deliberately independent from the local
identity and distribution changes. Keep future upstreamable fixes as separate
commits on top of `upstream/main`; open an upstream issue or pull request from
those commits without including the files that define this distribution.

## Daily use: use only CtriTerm

CtriTerm is the local app's user-facing name and is installed at
`/Applications/CtriTerm.app` (`0.1.27-ctrixin.380`). It replaced the prior
`CtriXin Glint.app` while retaining the same internal identity and all existing
local state. The installed `.380` release is Developer ID signed, Apple
notarized, and stapled, so it passes normal Gatekeeper verification on another
Mac.

`.380` carries the child-window exception guard: macOS retiring a background
view service while a popover, sheet, or menu is opening no longer takes the
whole app down. See `chenbstack/glint#98` for the upstream report.

- Launch **CtriTerm** from Spotlight, Finder, or `open -a "CtriTerm"`.
- Use it as the sole day-to-day Glint installation. It is safe to leave the
  upstream `/Applications/Glint.app` installed for comparison, but do not open
  it or use its in-app hook installer during normal work.
- CtriTerm uses its own Application Support, Keychain, URL scheme, agent
  socket, control socket, and usage cache. Existing terminal projects and
  shell configuration are still ordinary shared files, as they should be.
- CtriTerm retains its persistent workspaces across the display-name migration.
  New tabs (`Cmd-T`), splits (`Cmd-D` / `Cmd-Shift-D`), and workspaces (`Cmd-N`)
  inherit the focused terminal's directory when known.

After the one-time migration, do not rename the app bundle or change the
Bundle ID between updates. The stable application identity is what preserves
separate state and prevents recurring Keychain prompts.

## Signed release

A stable Developer ID signature lets macOS recognize this app as the same
Keychain client across rebuilds. The first request to access Claude Code's
credential may still require approval, and Claude token rotation can still
require a source Keychain read, but repeated prompts caused by ad-hoc build
identity churn should stop.

The following identity is already available locally and is suitable for this
purpose:

```text
Developer ID Application: xin song (2HJP9YYL3H)
```

Run a signed build with credentials kept in the login keychain:

```bash
DEVELOPMENT_TEAM=2HJP9YYL3H \
NOTARY_KEYCHAIN_PROFILE=<your-notary-profile> \
scripts/build-ctrixin-release.sh
```

`NOTARY_KEYCHAIN_PROFILE` is optional for a signed local build but required to
notarize and staple it for a normal Gatekeeper installation. Create it once in
the login Keychain, preferably from an Apple Developer API key (never commit
or share the `.p8` file):

```bash
xcrun notarytool store-credentials ctrixin-notary \
  --key "/secure/path/AuthKey_<key-id>.p8" \
  --key-id "<key-id>" \
  --issuer "<issuer-uuid>"

xcrun notarytool history --keychain-profile ctrixin-notary
```

Then build with `NOTARY_KEYCHAIN_PROFILE=ctrixin-notary`. The release script
re-signs Sparkle's embedded updater helpers with the same Developer ID and
secure timestamps, submits the app, waits for Apple's result, staples the
ticket, and validates it. The script never accepts or writes certificate
exports, Apple IDs, app-specific passwords, API keys, or Sparkle private keys.

Install the resulting `.app` from the printed archive path manually. Do not
replace upstream `Glint.app`; both apps may remain installed.

### Every iteration ships a GitHub release

This is the normal path for **every** update, not just milestone ones. An
iteration is not finished until it is tagged and published — a build that only
exists in `/Applications` cannot be reinstalled, verified, or rolled back to.

1. **Author the What's New entry first.** Add one `ReleaseNote` at the top of
   `ReleaseNotes.all` in `Glint/App/ReleaseNotes.swift`, with both `en` and `zh`.
   Its `version` must be the version that is about to ship, and the default
   version is `0.1.27-ctrixin.$(git rev-list --count HEAD)` — so author the
   entry and commit it, and the count *after* that commit is the number to
   write. Never pre-write an entry for a version you are not about to tag.
   `-ctrixin.N` sorts as a pre-release, so these entries roll up under the
   `0.1.27` base exactly like upstream betas do.
2. **Build, notarize, install.** Version defaults from the commit count, so no
   `VERSION=` override is normally needed:

   ```bash
   DEVELOPMENT_TEAM=2HJP9YYL3H \
   NOTARY_KEYCHAIN_PROFILE=ctrixin-notary \
   scripts/build-ctrixin-release.sh

   ditto "build/CtriTerm-<version>.xcarchive/Products/Applications/CtriTerm.app" \
     "/Applications/CtriTerm.app"
   ```

   Quit CtriTerm before replacing its bundle.
3. **Publish.** Package and attach the notarized ZIP plus its checksum:

   ```bash
   scripts/package-public-release.sh \
     "build/CtriTerm-<version>.xcarchive/Products/Applications/CtriTerm.app" <version>

   gh release create "ctriterm-v<version>" \
     dist/CtriTerm-<version>-macos-arm64-notarized.zip \
     dist/CtriTerm-<version>-macos-arm64-notarized.zip.sha256
   ```

No separate local backup of the previous bundle is kept: the published release
and the `build/` archive are the rollback path. This is deliberately a manual
update channel — upstream Sparkle is disabled and must stay disabled. Use
`NOTARY_KEYCHAIN_PROFILE=ctrixin-notary` for every distributed build.

Then verify `CtriTerm` in Finder's Get Info or Settings ▸ About.

### Restore after a system rebuild

Keep a notarized release ZIP outside Git before rebuilding macOS. After the
system is rebuilt, unzip it and copy `CtriTerm.app` to `/Applications`. The
backup should be unpacked and re-validated for both its Developer ID signature
and stapled notarization ticket. Git preserves source and the pushed local
branch, but not release archives, local workspace state, or login-Keychain
credentials. To restore workspaces too, back up
`~/Library/Application Support/CtriXin-Glint/`; CLI account credentials may
need reauthorization on a fresh macOS Keychain.

## Agent hook boundary

The local build uses separate bridge and external-control sockets under
`~/.ctrixin-glint/run/`; it will not steal those paths from upstream Glint.
Agent CLI configuration files such as `~/.claude/settings.json` are shared by
the two apps, so choose one app as the owner when using the in-app hook
installer. The generated reporter receives the destination socket from each
pane's environment, so ordinary sessions remain routed to the app that opened
them.

## Upstream sync

```bash
git fetch upstream --tags
git switch main
git merge --ff-only upstream/main
git switch local/ctrixin-distribution
git rebase main
```

Keep the local UI patches and the distribution patch as separate commits. This
preserves clean issue/PR candidates for `chenbstack/glint` while retaining the
local package identity and signing workflow.
