# Personal Homebrew tap

GTK 4 Zathura for macOS, with the MuPDF, DjVu, PostScript and comic-book plugins.

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

Patches are embedded in their owning formulae: API metadata in `synctex.rb`, initial forward-search queueing and macOS ZIP-container routing in `zathura-core.rb`, and the XPS MIME alias in `zathura-pdf-mupdf.rb`. They need no separate downloads or development workspace. The routing fix prevents XPS documents detected as generic ZIP files from going to the comic plugin.

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

On Intel Macs, replace `/opt/homebrew` with the Homebrew prefix. The callback requires VimTeX to load in the headless Neovim process as well as in the editing instance. VimTeX can supply its own callback through `-x`; `ZATHURA_SYNCTEX_EDITOR` is also supported. No smoke-test callback or editor dependency is bundled.

CLI and app launches share a private per-user bus at `/tmp/zathura-<uid>-homebrew`. The launcher checks ownership/permissions, serialises startup and restarts a dead bus on the next launch. It does not install a launchd job or run `brew services`.

## Maintenance and checks

Changes to app assets require a `zathura` revision bump. The app contains a copy of the core executable, so core updates also require rebuilding/bumping the top-level formula. An upstream plugin ABI change requires rebuilding the plugins together.

The existing Homebrew test-bot workflow builds/tests changed formulae and uploads bottles for pull requests; the publishing workflow retains the `pr-pull` label flow. Direct pushes do not publish bottles automatically. Until bottles are published, the custom formulae build from source.

Local packaging verification used fresh pinned source archives and the embedded patches, generated the manuals, compiled all four plugins, exercised the app formula’s assembly with staged dependency paths, verified its strict signature, opened two-page PDF/DjVu/PS/CBZ/CBT/XPS fixtures, and checked repeated forward SyncTeX and the parsed personal callback. XPS content was also opened with an `.oxps` extension; this is not a genuine OpenXPS conformance test. Launch Services listed the app as a Viewer for all 24 declared types.

A subsequent Homebrew source install and all seven formula tests passed, including strict verification of the installed app signature. Launch Services registration runs on normal viewer startup because Homebrew’s install sandbox blocks it. Published bottles have not been tested. The earlier handoff verified reload and real-click inverse search; those were not repeated for this package. RAR/7-Zip rendering, live-viewer bus reconnection, reboot recovery and Intel builds remain unverified. Trackpad smoothness is unchanged.
