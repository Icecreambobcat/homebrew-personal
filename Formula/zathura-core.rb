class ZathuraCore < Formula
  desc "GTK 4 document viewer and plugin development headers"
  homepage "https://pwmt.org/projects/zathura/"
  url "https://github.com/pwmt/zathura/archive/839f3192e96cc811033ebe500dab4ac11449d59d.tar.gz"
  version "2026.10.23"
  sha256 "ef11f15cb121fc6499136563d9f8b0ccdb2140dcd65e7a1338995ccaacd65970"
  license "Zlib"
  revision 2

  keg_only "the zathura formula provides the launcher and app"

  depends_on "gettext" => :build
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkgconf" => :build
  depends_on "sphinx-doc" => :build
  depends_on "cairo"
  depends_on "girara"
  depends_on "glib"
  depends_on "gtk4"
  depends_on "icecreambobcat/personal/synctex"
  depends_on "json-glib"
  depends_on "libmagic"
  depends_on :macos
  depends_on "sqlite"
  depends_on "xxhash"

  patch :DATA

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

__END__
diff --git a/zathura/main.c b/zathura/main.c
--- a/zathura/main.c
+++ b/zathura/main.c
@@ -26,6 +26,31 @@
 #if defined(WITH_SYNCTEX) && !defined(WITH_SANDBOX)
 #include "dbus-interface.h"
 #include "synctex.h"
 #endif
+
+#ifdef __APPLE__
+/* Silence this GTK warning without hiding other diagnostics. */
+static GLogWriterOutput filter_skipped_frame_warning(GLogLevelFlags level, const GLogField* fields,
+                                                    gsize n_fields, gpointer user_data) {
+  const char* domain = NULL;
+  const char* message = NULL;
+  for (gsize i = 0; i < n_fields; ++i) {
+    if (fields[i].length != -1) {
+      continue;
+    }
+    if (g_strcmp0(fields[i].key, "GLIB_DOMAIN") == 0) {
+      domain = fields[i].value;
+    } else if (g_strcmp0(fields[i].key, "MESSAGE") == 0) {
+      message = fields[i].value;
+    }
+  }
+  if ((level & G_LOG_LEVEL_MASK) == G_LOG_LEVEL_WARNING && !(level & G_LOG_FLAG_FATAL) &&
+      g_strcmp0(domain, "Gdk") == 0 &&
+      g_strcmp0(message, "gdk_frame_timings_presented() called on skipped frame.") == 0) {
+    return G_LOG_WRITER_HANDLED;
+  }
+  return g_log_writer_default(level, fields, n_fields, user_data);
+}
+#endif
-
+
 #if defined(WITH_SYNCTEX) && !defined(WITH_SANDBOX)
@@ -233,3 +258,6 @@
 /* main function */
 GIRARA_VISIBLE int main(int argc, char* argv[]) {
+#ifdef __APPLE__
+  g_log_set_writer_func(filter_skipped_frame_warning, NULL, NULL);
+#endif
   init_locale();
diff --git a/zathura/main.c b/zathura/main.c
--- a/zathura/main.c
+++ b/zathura/main.c
@@ -137,6 +137,7 @@ typedef struct {
   int page_number;
   char** argv;
   zathura_t* zathura;
+  bool opened_file;
 } zathura_app_ctx_t;
 
 static void cb_app_startup(GApplication* app, gpointer data) {
@@ -168,6 +169,49 @@ static void cb_app_open(GApplication* UNUSED(app), GFile** files, gint n_files,
     return;
   }
 
+#ifdef __APPLE__
+  /* Launch Services sends later open requests to the running app. Each
+   * document needs its own process, just like multiple CLI arguments. */
+  int first = ctx->opened_file ? 0 : 1;
+  ctx->opened_file = true;
+  for (int i = first; i < n_files; ++i) {
+    g_autofree char* child_path = g_file_get_path(files[i]);
+    if (child_path == NULL) {
+      girara_error("Failed to determine path for the given file.");
+      continue;
+    }
+    GPtrArray* args = g_ptr_array_new();
+    g_ptr_array_add(args, ctx->argv[0]);
+    if (ctx->config_dir) {
+      g_ptr_array_add(args, "--config-dir");
+      g_ptr_array_add(args, (gpointer)ctx->config_dir);
+    }
+    if (ctx->data_dir) {
+      g_ptr_array_add(args, "--data-dir");
+      g_ptr_array_add(args, (gpointer)ctx->data_dir);
+    }
+    if (ctx->cache_dir) {
+      g_ptr_array_add(args, "--cache-dir");
+      g_ptr_array_add(args, (gpointer)ctx->cache_dir);
+    }
+    if (ctx->plugin_path) {
+      g_ptr_array_add(args, "--plugins-dir");
+      g_ptr_array_add(args, (gpointer)ctx->plugin_path);
+    }
+    g_ptr_array_add(args, "--");
+    g_ptr_array_add(args, child_path);
+    g_ptr_array_add(args, NULL);
+    g_autoptr(GError) error = NULL;
+    if (!g_spawn_async(NULL, (char**)args->pdata, NULL, G_SPAWN_SEARCH_PATH, NULL, NULL, NULL, &error)) {
+      girara_error("Could not open document: %s", error->message);
+    }
+    g_ptr_array_free(args, TRUE);
+  }
+  if (first == 0) {
+    return;
+  }
+#endif
+
   /* gfile turns a plain dash into an absolute path which breaks stdin so keep the raw argument */
   g_autofree char* gfile_path = NULL;
   const char* path            = NULL;
diff --git a/zathura/content-type.c b/zathura/content-type.c
--- a/zathura/content-type.c
+++ b/zathura/content-type.c
@@ -116,6 +116,17 @@
                                  const girara_list_t* supported_content_types) {
   /* try libmagic first */
   g_autofree char* content_type = guess_type_magic(context, path);
+#ifdef __APPLE__
+  /* Launch Services can distinguish document containers that magic calls ZIP. */
+  g_autofree char* zip_type = g_content_type_from_mime_type("application/zip");
+  if (content_type != NULL && g_strcmp0(content_type, zip_type) == 0) {
+    g_autofree char* named_type = guess_type_glib(path);
+    if (named_type != NULL && supported_content_types != NULL &&
+        girara_list_find(supported_content_types, list_cmpstr, named_type) != NULL) {
+      return g_steal_pointer(&named_type);
+    }
+  }
+#endif
   if (content_type != NULL) {
     if (supported_content_types == NULL ||
         girara_list_find(supported_content_types, list_cmpstr, content_type) != NULL) {
diff --git a/zathura/synctex.c b/zathura/synctex.c
index 8e1696f..1ffcfbc 100644
--- a/zathura/synctex.c
+++ b/zathura/synctex.c
@@ -342,10 +342,21 @@ bool synctex_view(zathura_t* zathura, const char* input_file, unsigned int line,
     return false;
   }
 
-  zathura_document_t* document       = zathura_get_document(zathura);
-  const unsigned int number_of_pages = zathura_document_get_number_of_pages(document);
+  zathura_document_t* document = zathura_get_document(zathura);
+  if (document == NULL) {
+    return false;
+  }
 
-  unsigned int page                        = 0;
+  if (!zathura_document_widget_page_widgets_loaded(zathura->ui.document_widget)) {
+    g_free(zathura->sync.pending_synctex_input);
+    zathura->sync.pending_synctex_input  = g_strdup(input_file);
+    zathura->sync.pending_synctex_line   = line;
+    zathura->sync.pending_synctex_column = column;
+    return true;
+  }
+
+  const unsigned int number_of_pages = zathura_document_get_number_of_pages(document);
+  unsigned int page                      = 0;
   g_autoptr(girara_list_t) secondary_rects = NULL;
   g_autoptr(girara_list_t) rectangles      = synctex_rectangles_from_position(
       zathura, zathura_document_get_path(document), input_file, line, column, &page, &secondary_rects);
diff --git a/zathura/zathura.c b/zathura/zathura.c
index 2d9ca00..c7cd8f6 100644
--- a/zathura/zathura.c
+++ b/zathura/zathura.c
@@ -820,15 +820,20 @@ char* get_formatted_filename(zathura_t* zathura, bool statusbar) {
 }
 
 static void cb_document_widget_page_widgets_loaded(ZathuraDocumentWidget* document_widget, zathura_t* zathura) {
-  if (document_widget != zathura->ui.document_widget || zathura->sync.pending_search_input == NULL) {
+  if (document_widget != zathura->ui.document_widget) {
     return;
   }
 
-  char* input                        = zathura->sync.pending_search_input;
-  zathura->sync.pending_search_input = NULL;
-  girara_argument_t argument         = {.n = zathura->sync.pending_search_direction};
-  cmd_search(zathura->ui.session, input, &argument);
-  g_free(input);
+  if (zathura->sync.pending_search_input != NULL) {
+    g_autofree char* input      = g_steal_pointer(&zathura->sync.pending_search_input);
+    girara_argument_t argument = {.n = zathura->sync.pending_search_direction};
+    cmd_search(zathura->ui.session, input, &argument);
+  }
+
+  if (zathura->sync.pending_synctex_input != NULL) {
+    g_autofree char* input = g_steal_pointer(&zathura->sync.pending_synctex_input);
+    synctex_view(zathura, input, zathura->sync.pending_synctex_line, zathura->sync.pending_synctex_column);
+  }
 }
 
 static bool document_widget_create(zathura_t* zathura, zathura_document_t* document, unsigned int page_v_padding,
@@ -1465,6 +1470,7 @@ bool document_close(zathura_t* zathura, bool keep_monitor) {
   }
   g_free(zathura->sync.pending_search_input);
   zathura->sync.pending_search_input = NULL;
+  g_clear_pointer(&zathura->sync.pending_synctex_input, g_free);
 
   /* drop a first render hold that never got released */
   initial_render_cancel_hold(zathura);
diff --git a/zathura/zathura.h b/zathura/zathura.h
index 1cb8de5..fac10f2 100644
--- a/zathura/zathura.h
+++ b/zathura/zathura.h
@@ -132,6 +132,9 @@ struct zathura_s {
     GObject* initial_render_instance; /**< instance the release handler is connected to */
     char* pending_search_input;       /**< search query received before the widgets finished loading */
     int pending_search_direction;     /**< direction for a search received before loading finished */
+    char* pending_synctex_input;      /**< SyncTeX source received before the widgets finished loading */
+    unsigned int pending_synctex_line;
+    unsigned int pending_synctex_column;
   } sync;
 
   struct {
