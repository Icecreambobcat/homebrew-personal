class ZathuraPdfMupdf < Formula
  desc "MuPDF document plugin for Zathura"
  homepage "https://pwmt.org/projects/zathura-pdf-mupdf/"
  url "https://github.com/pwmt/zathura-pdf-mupdf/archive/02896d8a7f58a5b0596f62dc083b23a11d6e6e93.tar.gz"
  version "2026.07.18"
  sha256 "685027642478441e532afe04b1fb6fe35c604f727b5b0fe690ac7a345a3e9ed8"
  license "Zlib"

  depends_on "gettext" => :build
  depends_on "icecreambobcat/personal/zathura-core" => :build
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkgconf" => :build
  depends_on "cairo"
  depends_on "girara"
  depends_on "glib"
  depends_on :macos
  depends_on "mupdf"

  patch :DATA

  def install
    system "meson", "setup", "build", *std_meson_args, "-Dplugindir=#{lib}/zathura"
    system "meson", "compile", "-C", "build"
    system "meson", "install", "-C", "build"
  end

  test do
    assert_path_exists lib/"zathura/libpdf-mupdf.dylib"
  end
end

__END__
diff --git a/zathura-pdf-mupdf/plugin.c b/zathura-pdf-mupdf/plugin.c
--- a/zathura-pdf-mupdf/plugin.c
+++ b/zathura-pdf-mupdf/plugin.c
@@ -30,6 +30,7 @@
                                        }),
                                        ZATHURA_PLUGIN_MIMETYPES({
                                            PDF_MIMETYPE "application/oxps",
+                                           "application/vnd.ms-xpsdocument",
                                            "application/epub+zip",
                                            "application/x-fictionbook",
                                            "application/x-mobipocket-ebook",
