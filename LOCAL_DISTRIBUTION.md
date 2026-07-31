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
