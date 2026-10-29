class ZathuraPs < Formula
  desc "PostScript document plugin for Zathura"
  homepage "https://pwmt.org/projects/zathura-ps/"
  url "https://github.com/pwmt/zathura-ps/archive/db495a049ac8cb521cd867084e6334a1b16edd9f.tar.gz"
  version "2026.07.18"
  sha256 "61a8cf366a753ba99fb68031d53606bf92de61f96f87afcfbb47ec2148d82449"
  license "Zlib"

  bottle do
    root_url "https://github.com/Icecreambobcat/homebrew-personal/releases/download/zathura-ps-2026.07.18"
    rebuild 1
    sha256 cellar: :any, arm64_golden_gate: "249309900be3948f4e667912a4898a92f6de6e6cbfc4f78ebba6ac12ea35b8f6"
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
  depends_on "libspectre"
  depends_on macos: :golden_gate

  def install
    system "meson", "setup", "build", *std_meson_args, "-Dplugindir=#{lib}/zathura"
    system "meson", "compile", "-C", "build"
    system "meson", "install", "-C", "build"
  end

  test do
    assert_path_exists lib/"zathura/libps.dylib"
  end
end
