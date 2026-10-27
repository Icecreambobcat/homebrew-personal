class Synctex < Formula
  desc "TeX synchronisation parser with corrected API metadata"
  homepage "https://github.com/jlaurens/synctex"
  url "https://github.com/jlaurens/synctex/archive/0668445124169be0be18d4b768cdf1be0b11a994.tar.gz"
  version "2024"
  sha256 "afd83bb58f5563272d1b78da2510564b06faf6162bb4ad179afae8c368c2865f"
  license "MIT"

  keg_only "avoid shadowing the SyncTeX command supplied by TeX distributions"

  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkgconf" => :build
  depends_on :macos
  depends_on "zlib"

  patch :DATA

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

__END__
diff --git a/meson.build b/meson.build
index a940709..f9c3818 100644
--- a/meson.build
+++ b/meson.build
@@ -1,6 +1,7 @@
 project('synctex', 'c')
 
-version = '1.3'
+# Keep aligned with synctex_parser_api_level.txt, not the parser release version.
+version = '2.0.0'
 
 pkg = import('pkgconfig')
 
@@ -35,16 +36,18 @@ synctex_dep = declare_dependency(
   link_with: synctex_lib,
 )
 
+# Preserve the legacy flat include layout as well as namespaced consumers.
 install_headers(headers)
+install_headers(headers, subdir: 'synctex')
 
 pkg.generate(
   name: 'synctex',
   version: version,
-  libraries: 'synctex',
-  subdirs: 'synctex',
+  libraries: synctex_lib,
+  subdirs: '.',
   description: 'SyncTeX parser library',
-  url: 'http://github.org/jlaurens/synctex',
-  install_dir: join_paths(get_option('prefix'), 'lib', 'pkgconfig'),
+  url: 'https://github.com/jlaurens/synctex',
+  install_dir: join_paths(get_option('libdir'), 'pkgconfig'),
 )
 
 synctex_src = include_directories('.')
