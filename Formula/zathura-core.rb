class ZathuraCore < Formula
  desc "GTK 4 document viewer and plugin development headers"
  homepage "https://pwmt.org/projects/zathura/"
  url "https://github.com/Icecreambobcat/zathura/archive/c1060fec481cfde16f53097d0f6d35a58cf38e77.tar.gz"
  version "2026.10.23"
  sha256 "2535436cf8bec6600ca5b1992f3180106f4ab436ed68f533692b895c3c8a9aee"
  license "Zlib"
  revision 8

  keg_only "the zathura formula provides the launcher and app"

  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkgconf" => :build
  depends_on "sphinx-doc" => :build
  depends_on arch: :arm64
  depends_on "cairo"
  depends_on "gettext"
  depends_on "girara"
  depends_on "glib"
  depends_on "graphene"
  depends_on "gtk4"
  depends_on "icecreambobcat/personal/synctex"
  depends_on "json-glib"
  depends_on "libmagic"
  depends_on macos: :golden_gate
  depends_on "pango"
  depends_on "sqlite"
  depends_on "xxhash"

  def install
    system "meson", "setup", "build", *std_meson_args,
           "-Dsynctex=enabled", "-Dseccomp=disabled", "-Dlandlock=disabled",
           "-Dmanpages=enabled", "-Dshell-completions=enabled", "-Dconvert-icon=disabled",
           "-Dtests-x11=disabled", "-Dtests-wayland=disabled"
    system "meson", "compile", "-C", "build"
    system "meson", "install", "-C", "build"
    libexec.install bin/"zathura"
  end

  test do
    assert_match version.to_s, shell_output("#{libexec}/zathura --version")
    assert_path_exists include/"zathura/plugin-api.h"
    assert_match "abiversion=9", (lib/"pkgconfig/zathura.pc").read
  end
end
