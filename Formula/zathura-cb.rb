class ZathuraCb < Formula
  desc "Comic book archive plugin for Zathura"
  homepage "https://pwmt.org/projects/zathura-cb/"
  url "https://github.com/pwmt/zathura-cb/archive/6850dd5897b8cb521e12e5dee39bf7861b899bc1.tar.gz"
  version "2026.07.18"
  sha256 "ec5d3a2d32be57ec5da92868687a851b7d051980c60e988ef566e5858e51778d"
  license "Zlib"
  revision 2

  bottle do
    root_url "https://github.com/Icecreambobcat/homebrew-personal/releases/download/zathura-cb-2026.07.18_2"
    sha256 cellar: :any, arm64_golden_gate: "34d6201fae0c6b974e591caf2474e210d6f0007ea4a78494d10f779eb6d256f8"
  end

  depends_on "gettext" => :build
  depends_on "icecreambobcat/personal/zathura-core" => :build
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkgconf" => :build
  depends_on arch: :arm64
  depends_on "cairo"
  depends_on "gdk-pixbuf"
  depends_on "girara"
  depends_on "glib"
  depends_on "gtk4"
  depends_on "libarchive"
  depends_on macos: :golden_gate

  def install
    system "meson", "setup", "build", *std_meson_args, "-Dplugindir=#{lib}/zathura"
    system "meson", "compile", "-C", "build"
    system "meson", "install", "-C", "build"
  end

  test do
    assert_path_exists lib/"zathura/libcb.dylib"
  end
end
