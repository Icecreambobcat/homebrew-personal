class ZathuraDjvu < Formula
  desc "DjVu document plugin for Zathura"
  homepage "https://pwmt.org/projects/zathura-djvu/"
  url "https://github.com/pwmt/zathura-djvu/archive/22e1be11de171747f66178e1256c2352a290b175.tar.gz"
  version "2026.07.18"
  sha256 "c114769a8db1bea50890e4508d80864648291439be996c7bf7e33e237082339f"
  license "Zlib"
  revision 1

  depends_on "gettext" => :build
  depends_on "icecreambobcat/personal/zathura-core" => :build
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkgconf" => :build
  depends_on "cairo"
  depends_on "djvulibre"
  depends_on "girara"
  depends_on "glib"
  depends_on :macos

  def install
    system "meson", "setup", "build", *std_meson_args, "-Dplugindir=#{lib}/zathura"
    system "meson", "compile", "-C", "build"
    system "meson", "install", "-C", "build"
  end

  test do
    assert_path_exists lib/"zathura/libdjvu.dylib"
  end
end
