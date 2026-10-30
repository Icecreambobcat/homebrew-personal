# Personal Homebrew tap

GTK 4 Zathura for Apple Silicon Macs running macOS 27 or later, with the MuPDF, DjVu, PostScript and comic-book plugins. Intel Macs are not supported.

## Install

```sh
brew tap icecreambobcat/personal
brew trust --tap icecreambobcat/personal
brew install icecreambobcat/personal/zathura
```

The single install brings in every component below. The formula installs no personal config or editor and does not set default file handlers. Its private D-Bus needs no Homebrew service.

```sh
zathura document.pdf
open -a "$(brew --prefix zathura)/Zathura.app" document.pdf
```

The app depends on Homebrew libraries. It is not a standalone app that can be copied to another Mac.

On macOS, document windows share one regular native app process and Dock icon. Reopening a document reuses its window; `q` or Cmd-W closes one window, while Cmd-Q quits the app. Page state, settings and SyncTeX callbacks belong to each document window. The mapped-surface size override prevents GTK from restoring a stale size over a yabai resize.

## Components, in dependency order

| Order | Formula | Purpose |
| --- | --- | --- |
| 1 | `girara` and renderer/toolkit libraries from Homebrew core | Unmodified upstream dependencies |
| 1 | `icecreambobcat/personal/synctex` | Pinned 2024 parser, corrected API 2.0.0 metadata and both header layouts |
| 2 | `icecreambobcat/personal/zathura-core` | Pinned 2026.10.23 GTK 4 viewer, plugin headers, manuals and completions |
| 3 | `icecreambobcat/personal/zathura-pdf-mupdf` | PDF, XPS/OpenXPS, EPUB, FictionBook, Mobipocket, XML and images |
| 3 | `icecreambobcat/personal/zathura-djvu` | DjVu |
| 3 | `icecreambobcat/personal/zathura-ps` | PostScript and EPS through libspectre/Ghostscript |
| 3 | `icecreambobcat/personal/zathura-cb` | ZIP, RAR, 7-Zip and TAR image archives, comic extensions and image folders |
| 4 | `icecreambobcat/personal/zathura` | CLI launcher, app bundle, supplied icon and file-type registration |

The four plugins use the core headers at build time; the final app depends on all four plugins and the core. This avoids a circular dependency. MuPDF is the PDF backend; Poppler is not installed alongside it.

Custom sources are pinned by commit and SHA-256. The unmodified Homebrew dependencies, including Girara, follow Homebrew core rather than being frozen by this tap.

The macOS changes live in the `macos` branches of the [Zathura](https://github.com/Icecreambobcat/zathura/tree/macos), [SyncTeX](https://github.com/Icecreambobcat/synctex/tree/macos) and [MuPDF plugin](https://github.com/Icecreambobcat/zathura-pdf-mupdf/tree/macos) forks. Formulae download immutable commit archives with SHA-256 checksums; there are no embedded patches. The [development workspace](https://github.com/Icecreambobcat/zathura-macos) records all seven components as submodules and builds editable sources separately from the installed app. The ZIP-container routing fix keeps XPS documents out of the comic plugin.

## App and default openers

The app is installed at `$(brew --prefix zathura)/Zathura.app`. The launcher registers its document types with Launch Services when opening the viewer; launch it once after installation. Registration cannot run inside Homebrew’s install sandbox. An optional Finder-visible link can be created without copying the bundle:

```sh
mkdir -p ~/Applications
ln -s "$(brew --prefix zathura)/Zathura.app" ~/Applications/Zathura.app
```

If that destination already exists, inspect it rather than replacing it blindly.

For each desired file type, select a representative file in Finder, choose **Get Info → Open with → Zathura → Change All**. Use **Other…** to select the app at the path above if it is not listed. Registration uses the Viewer role and Alternate rank; the formula never calls a default-handler setter. Document declarations follow [Apple’s Launch Services keys](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundledocumenttypes).

The supplied 200 × 200 PNG is kept in `assets/zathura/icon.png`; `Zathura.icns` contains its resized icon representations. Upscaling does not add detail.

## Personal configuration and VimTeX

The formula installs no `zathurarc`. Keep settings in `~/.config/zathura/zathurarc` or `$XDG_CONFIG_HOME/zathura/zathurarc`. The reviewed theme, scrolling, clipboard and inverse-search settings are managed separately in the dotfiles repository.

For Neovim with VimTeX:

```vim
let g:vimtex_view_method = 'zathura_simple'
```

Set an inverse callback in `zathurarc`, using the installed Neovim path:

```text
set synctex true
set synctex-editor-command "/opt/homebrew/bin/nvim --headless -c \"VimtexInverseSearch %{line}:%{column} '%{input}'\""
```

The callback requires VimTeX to load in the headless Neovim process as well as in the editing instance. VimTeX can supply its own callback through `-x`; `ZATHURA_SYNCTEX_EDITOR` is also supported. No smoke-test callback or editor dependency is bundled.

CLI and app launches share a private per-user bus at `/tmp/zathura-<uid>/bus`. The launcher checks ownership/permissions, serialises startup and restarts a dead bus on the next launch. It does not install a launchd job or run `brew services`.


## Dependency upgrades and release procedure

Source pins do not freeze Homebrew runtime libraries. Packaging unchanged upstream
code still requires rebuilding its consumers when binary compatibility changes.

- Rebuild the MuPDF plugin for each MuPDF version change unless compatibility is
  explicitly verified. Never bypass its version guard.
- Compare bottle receipts with current dependency compatibility metadata using
  `python3 scripts/check-zathura-dependencies.py`. Investigate changed compatibility
  values and rebuild affected consumers; ordinary compatible updates need no blanket rebuild.
- Keep core and app revisions aligned because the app copies the core executable.
  Rebuild plugins for plugin API/ABI changes. Source changes are not required for
  a packaging revision bump.
- Keep plugin symlinks on `opt` paths. Check the raw targets after a named-formula
  bottle pour, not just after building. Declarative post-install steps restore links.
- Test published bottles against current dependencies before rebuilding consumers.
  The daily compatibility workflow does this without silently rebuilding the stack.
  A failed run requires a reviewed revision bump and replacement bottles.

Before remote CI, build, bottle and locally pour all seven packages in dependency
order. Use `brew install --build-bottle`, then `brew bottle --json`; neither
`upgrade` nor `reinstall` accepts `--build-bottle`. Use a temporary loopback bottle
URL with the named formula, verify `poured_from_bottle` in receipts, and restore
publication metadata before committing. Run `brew postinstall` after local
reinstalls: Homebrew can preserve build-bottle mode and skip signature/link repair.
Run formula tests, `brew linkage --test --strict`, signature checks and real
document tests on the poured stack.
Run `python3 "$(brew --prefix zathura)/share/zathura/smoke-test.py"
"$(brew --prefix zathura)/Zathura.app"
"$(brew --repository)/Library/Homebrew/test/support/fixtures" "$(brew --prefix)"`
to open and render PDF, DjVu, PostScript and comic fixtures in a disposable app
with a private bus. Release and maintenance CI require this outside the formula-test
sandbox, which prevents macOS GUI registration. Dylib existence and `--version` are not
sufficient tests. Run the separate real-fixture SyncTeX/multiwindow regression too.

Push the locally validated branch over SSH and open a PR. Require all seven CI
bottle artifacts and passing checks before applying `pr-pull`. Verify public
named-formula pours after publication. Fast-forward the installed tap and align
the workspace packaging gitlink to the resulting published main commit; publication
cherry-picks can give it a different hash from the tested branch.

Preserve personal configuration, default handlers and existing document windows.
Remove generated builds, fixtures, staging files, temporary bottle metadata and
local bottles after verification; retain reports. Stop only test-owned D-Bus daemons.

## Earlier verification

Changes to app assets require a `zathura` revision bump. The app contains a copy of the core executable, so core updates also require rebuilding/bumping the top-level formula. An upstream plugin ABI change requires rebuilding the plugins together.

The Homebrew test-bot workflow targets macOS 27 on Apple Silicon using GitHub's [`xcode-27` runner](https://github.com/actions/runner-images#available-images). Zathura-related pull requests and manual runs build all seven packages and require all seven `arm64_golden_gate` bottles. Other pull requests use changed-formula detection. Validate local source builds, bottle pours, strict linkage and formula tests before running CI. The publishing workflow uses the `pr-pull` label. Direct pushes do not publish bottles automatically. Until bottles are published, the custom formulae build from source.

All seven packages passed clean source builds, bottling and named-formula bottle installs locally on macOS 27/Apple Silicon. Both the source installs and bottle pours passed strict linkage checks and formula tests; install receipts confirmed the pours used bottles. The poured app passed strict signature verification and the live multi-window regression. Revision 8 builds from the tracked fork archives. Homebrew type checking, changed-formula style checks and strict audit also passed locally. Native ASan/UBSan tests passed, including session isolation, pending-open cancellation and inverse-callback source routing. Live geometry regression passed eight float/retile cycles and six neighbouring-window open/close cycles in both the isolated test app and the installed app. The installed app also passed Launch Services multi-file reuse, stdin cleanup and independent document closure.

Physical Ctrl-clicks in both installed-app PDFs reached their own separate VimTeX editors at source line 3, column 1. AppKit reported one regular native app, with the Mach-O viewer as its bundle executable; Launch Services listed it as a PDF opener candidate without changing defaults.

RAR/7-Zip rendering, live-viewer bus reconnection and reboot recovery remain unverified. Trackpad smoothness was not changed.
