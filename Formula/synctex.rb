class Synctex < Formula
  desc "TeX synchronisation parser with corrected API metadata"
  homepage "https://github.com/jlaurens/synctex"
  url "https://github.com/Icecreambobcat/synctex/archive/5b29cf44a6f46d77e14d18129307744be7bd5fe7.tar.gz"
  version "2024"
  sha256 "59ed88840bdbf10879de4e9b290a39e182e67446ef9f4057e967318683eb3218"
  license "MIT"
  revision 1

  bottle do
    root_url "https://github.com/Icecreambobcat/homebrew-personal/releases/download/synctex-2024_1"
    sha256 cellar: :any, arm64_golden_gate: "98c0f59407e43fda26df6a53b3acb248ad7c06fe6f1325dba8ceb8accd5a1f79"
  end

  keg_only "avoid shadowing the SyncTeX command supplied by TeX distributions"

  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkgconf" => :build
  depends_on arch: :arm64
  depends_on macos: :golden_gate
  depends_on "zlib"

  def install
    system "meson", "setup", "build", *std_meson_args
    system "meson", "compile", "-C", "build"
    system "meson", "install", "-C", "build"
  end

  test do
    assert_path_exists include/"synctex_parser.h"
    assert_path_exists include/"synctex/synctex_parser.h"
    assert_match "Version: 2.0.0", (lib/"pkgconfig/synctex.pc").read
    assert_match "SyncTeX", shell_output("#{bin}/synctex help")
  end
end
