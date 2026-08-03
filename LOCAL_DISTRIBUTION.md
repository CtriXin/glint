# Local Distribution

This fork installs alongside upstream Glint as **CtriXin Glint**.

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

## Daily use: use only CtriXin Glint

The installed local app is `/Applications/CtriXin Glint.app`:

- Current installed version: `0.1.27-ctrixin.367` (`202607311005`).
- Launch **CtriXin Glint** from Spotlight, Finder, or
  `open -a "CtriXin Glint"`.
- Use it as the sole day-to-day Glint installation. It is safe to leave the
  upstream `/Applications/Glint.app` installed for comparison, but do not open
  it or use its in-app hook installer during normal work.
- The two apps do not share Glint state: CtriXin uses its own Application
  Support, Keychain, URL scheme, agent socket, control socket, and usage cache.
  Existing terminal projects and shell configuration are still ordinary shared
  files, as they should be.
- CtriXin has its own persistent workspaces. Open a folder or create a
  workspace once in CtriXin, then use that app for its subsequent tabs, splits,
  and workspaces. New tabs (`Cmd-T`), splits (`Cmd-D` / `Cmd-Shift-D`), and
  workspaces (`Cmd-N`) inherit the focused terminal's directory when known.

Do not uninstall, rename, or change the Bundle ID of CtriXin Glint between
updates. The stable application identity is what preserves separate state and
prevents recurring Keychain prompts.

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
notarize and staple it for a normal Gatekeeper installation. The script never
accepts or writes certificate exports, Apple IDs, app-specific passwords, or
Sparkle private keys.

Install the resulting `.app` from the printed archive path manually. Do not
replace upstream `Glint.app`; both apps may remain installed.

### Repeatable local update procedure

Every future local build should use this same package identity and signing
certificate. Choose a version higher than the installed version, create a new
archive, quit CtriXin Glint, and replace only its app bundle:

```bash
VERSION=0.1.27-ctrixin.368 \
DEVELOPMENT_TEAM=2HJP9YYL3H \
scripts/build-ctrixin-release.sh

ditto "build/CtriXin-Glint-0.1.27-ctrixin.368.xcarchive/Products/Applications/CtriXin Glint.app" \
  "/Applications/CtriXin Glint.app"
```

Then verify `CtriXin Glint` in Finder's Get Info or Settings > About. Keep the
previous archive until the new build has opened successfully, so rollback is a
single app-bundle replacement. This is deliberately a manual local update
channel: upstream Sparkle is disabled and must stay disabled. The current
build is Developer ID signed but not notarized; notarize future packages with
`NOTARY_KEYCHAIN_PROFILE` before distributing them to another Mac.

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
