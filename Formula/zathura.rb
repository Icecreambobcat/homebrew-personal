class Zathura < Formula
  desc "GTK 4 Zathura app with MuPDF, DjVu, PostScript and comic plugins"
  homepage "https://pwmt.org/projects/zathura/"
  url "https://github.com/Icecreambobcat/zathura/archive/c1060fec481cfde16f53097d0f6d35a58cf38e77.tar.gz"
  version "2026.10.23"
  sha256 "2535436cf8bec6600ca5b1992f3180106f4ab436ed68f533692b895c3c8a9aee"
  license "Zlib"
  revision 8

  depends_on "cairo"
  depends_on "dbus"
  depends_on "gettext"
  depends_on "girara"
  depends_on "glib"
  depends_on "graphene"
  depends_on "gtk4"
  depends_on "icecreambobcat/personal/synctex"
  depends_on "icecreambobcat/personal/zathura-cb"
  depends_on "icecreambobcat/personal/zathura-core"
  depends_on "icecreambobcat/personal/zathura-djvu"
  depends_on "icecreambobcat/personal/zathura-pdf-mupdf"
  depends_on "icecreambobcat/personal/zathura-ps"
  depends_on "json-glib"
  depends_on "libmagic"
  depends_on :macos
  depends_on "pango"
  depends_on "python@3.15"
  depends_on "sqlite"
  depends_on "xxhash"

  def install
    assets = tap.path/"assets/zathura"
    app = prefix/"Zathura.app"
    macos = app/"Contents/MacOS"
    resources = app/"Contents/Resources"
    core = Formula["icecreambobcat/personal/zathura-core"]
    mkdir_p macos
    mkdir_p resources
    cp core.opt_libexec/"zathura", macos/"zathura"
    cp assets/"launcher.py", resources/"launcher.py"
    inreplace resources/"launcher.py" do |s|
      s.gsub! "@@PYTHON@@", (formula_opt_bin("python@3.15")/"python3.15").to_s
      s.gsub! "@@HOMEBREW_PREFIX@@", HOMEBREW_PREFIX.to_s
      s.gsub! "@@GDBUS@@", (formula_opt_bin("glib")/"gdbus").to_s
      s.gsub! "@@DBUS@@", (formula_opt_bin("dbus")/"dbus-daemon").to_s
      s.gsub! "@@PLUGINS@@", (opt_libexec/"plugins").to_s
      s.gsub! "@@RUNTIME@@", "zathura"
    end
    chmod 0755, resources/"launcher.py"
    cp assets/"Info.plist", app/"Contents/Info.plist"
    system "/usr/libexec/PlistBuddy", "-c", "Set :CFBundleVersion #{version}.#{revision}",
           app/"Contents/Info.plist"
    cp assets/"Zathura.icns", resources/"Zathura.icns"
    cp assets/"session.conf", resources/"session.conf"
    %w[zathura-pdf-mupdf zathura-djvu zathura-ps zathura-cb].each do |name|
      (libexec/"plugins").install_symlink Dir[formula_opt_lib("icecreambobcat/personal/#{name}")/"zathura/*.dylib"]
    end
    bin.mkpath
    (bin/"zathura").write <<~SH
      #!/bin/sh
      exec "#{opt_prefix}/Zathura.app/Contents/MacOS/zathura" "$@"
    SH
    chmod 0755, bin/"zathura"
    man1.install_symlink core.opt_share/"man/man1/zathura.1"
    man5.install_symlink core.opt_share/"man/man5/zathurarc.5"
    bash_completion.install_symlink core.opt_share/"bash-completion/completions/zathura"
    zsh_completion.install_symlink core.opt_share/"zsh/site-functions/_zathura"
    fish_completion.install_symlink core.opt_share/"fish/vendor_completions.d/zathura.fish"
    system "/usr/bin/plutil", "-lint", app/"Contents/Info.plist"
    system "/usr/bin/codesign", "--force", "--deep", "--sign", "-", app
  end

  post_install_steps do
    # Bottle relocation may change Mach-O load paths after the build-time signature.
    run "/usr/bin/codesign",
        args:           ["--force", "--deep", "--sign", "-", "{{opt_prefix}}/Zathura.app"],
        writable_paths: ["Zathura.app"]
  end

  def caveats
    <<~EOS
      Open the app with:
        open -a "#{opt_prefix}/Zathura.app"

      Launch the app once to register its file types.
      To show it in ~/Applications, create a symlink to:
        #{opt_prefix}/Zathura.app

      Choose Zathura in Finder > Get Info > Open with > Change All
      separately for each desired file type. Installation does not change defaults.

      Personal settings belong in ~/.config/zathura/zathurarc.
      Set synctex-editor-command there, pass -x, or set ZATHURA_SYNCTEX_EDITOR.
      No editor or personal configuration is installed by this formula.

      The app uses a private per-user D-Bus, not a global brew service.
      This app depends on Homebrew libraries; it is not a standalone bundle.
    EOS
  end

  test do
    output = shell_output("#{bin}/zathura --version")
    assert_match version.to_s, output
    %w[pdf-mupdf djvu ps cb].each { |name| assert_match name, output }
    system "/usr/bin/plutil", "-lint", prefix/"Zathura.app/Contents/Info.plist"
    assert_path_exists prefix/"Zathura.app/Contents/Resources/Zathura.icns"
    assert_match "Mach-O", shell_output("/usr/bin/file #{prefix}/Zathura.app/Contents/MacOS/zathura")
    system "/usr/bin/codesign", "--verify", "--deep", "--strict", prefix/"Zathura.app"
  end
end
