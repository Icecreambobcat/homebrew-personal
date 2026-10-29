class ZathuraPdfMupdf < Formula
  desc "MuPDF document plugin for Zathura"
  homepage "https://pwmt.org/projects/zathura-pdf-mupdf/"
  url "https://github.com/Icecreambobcat/zathura-pdf-mupdf/archive/37440c30ebafcb17d0567522df6ef1fb4cf2f02a.tar.gz"
  version "2026.07.18"
  sha256 "edf9849826ec91c3aa1268675d0ebfd0f72cc10dbba89c57fa8f634344c8ecfe"
  license "Zlib"
  revision 1

  bottle do
    root_url "https://github.com/Icecreambobcat/homebrew-personal/releases/download/zathura-pdf-mupdf-2026.07.18_1"
    sha256 cellar: :any, arm64_golden_gate: "57fddbeded9cb8c0014d7819589b9fbe97096f7decb0b4ec56cb5cb242ef2f9c"
  end

  depends_on "gettext" => :build
  depends_on "icecreambobcat/personal/zathura-core" => :build
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkgconf" => :build
  depends_on arch: :arm64
  depends_on "cairo"
  depends_on "girara"
  depends_on "glib"
  depends_on macos: :golden_gate
  depends_on "mupdf"

  def install
    system "meson", "setup", "build", *std_meson_args, "-Dplugindir=#{lib}/zathura"
    system "meson", "compile", "-C", "build"
    system "meson", "install", "-C", "build"
  end

  test do
    assert_path_exists lib/"zathura/libpdf-mupdf.dylib"
  end
end
