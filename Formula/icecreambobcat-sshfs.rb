require_relative "../require/macfuse"
require_relative "../require/formula"

class IcecreambobcatSshfs < Formula
  desc "Network filesystem client to connect to SSH servers"
  homepage "https://github.com/libfuse/sshfs"
  url "https://github.com/libfuse/sshfs/archive/refs/tags/sshfs-3.7.5.tar.gz"
  sha256 "99d294101f1b8997653a84c35674c2e50c18323ea2c449412c0ed46b9d31ac35"
  license any_of: ["LGPL-2.1-only", "GPL-2.0-only"]

  depends_on "coreutils" => :build
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkgconf" => :build
  depends_on "glib"
  depends_on MacfuseRequirement
  depends_on :macos

  def install
    setup_fuse3
    ENV.prepend_path "PATH", Formula["coreutils"].libexec/"gnubin" if OS.mac?
    system "meson", "setup", "build", *std_meson_args
    system "meson", "compile", "-C", "build", "--verbose"
    system "meson", "install", "-C", "build"
  end

  test do
    system "#{bin}/sshfs", "--version"
  end
end
