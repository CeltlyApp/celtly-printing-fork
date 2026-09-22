package net.nfet.flutter.printing;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.ClipData;
import android.net.Uri;
import androidx.core.content.FileProvider;
import java.io.File;
import java.io.IOException;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/** Shares an already closed, verified, immutable app-private PDF. No copying. */
final class CeltlyShareFile {
    static final int REQUEST = 0xCE14;
    private static MethodChannel.Result pending;

    static void share(Context context, MethodCall call, MethodChannel.Result result) {
        if (pending != null || !(context instanceof Activity) ||
                ((Activity) context).isFinishing() || ((Activity) context).isDestroyed() ||
                !((Activity) context).hasWindowFocus()) {
            result.error("share-unavailable", "Could not open sharing.", null);
            return;
        }
        try {
            Object path = call.argument("path"), length = call.argument("bytes");
            Object hash = call.argument("sha256");
            if (!(path instanceof String) || !(length instanceof Number) ||
                    !(hash instanceof String) || !((String) hash).matches("[a-f0-9]{64}"))
                throw new IOException();
            File root = new File(context.getCacheDir(), "share/celtly-report-share-v1").getCanonicalFile();
            File file = new File((String) path);
            String canonical = file.getCanonicalPath();
            String prefix = root.getPath() + File.separator;
            if (!canonical.equals(file.getAbsolutePath()) || !canonical.startsWith(prefix) ||
                    !canonical.substring(prefix.length()).matches("op_[A-Za-z0-9]+/[A-Za-z0-9][A-Za-z0-9._-]{0,179}\\.pdf") ||
                    file.getName().contains("..") || !file.isFile() || !file.canRead() ||
                    ((Number) length).longValue() <= 0 || ((Number) length).longValue() > 80L * 1024 * 1024 ||
                    file.length() != ((Number) length).longValue()) throw new IOException();
            // Dart verified SHA-256 immediately before this synchronous handoff.
            // Receiver gets read access only. Exposed files are never overwritten.
            Intent send = new Intent(Intent.ACTION_SEND);
            send.setType("application/pdf");
            Uri uri = FileProvider.getUriForFile(context,
                    context.getApplicationContext().getPackageName() + ".flutter.printing", file);
            send.putExtra(Intent.EXTRA_STREAM, uri);
            send.setClipData(ClipData.newRawUri("", uri));
            send.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            pending = result;
            ((Activity) context).startActivityForResult(Intent.createChooser(send, null), REQUEST);
        } catch (Exception error) {
            if (pending == result) pending = null;
            result.error("share-unavailable", "Could not open sharing.", null);
        }
    }

    static boolean completed(int requestCode) {
        if (requestCode != REQUEST) return false;
        MethodChannel.Result result = pending; pending = null;
        // Chooser result is not proof of consumption, cancellation or delivery.
        if (result != null) result.success("unknown");
        return true;
    }

    static void detached() {
        MethodChannel.Result result = pending; pending = null;
        if (result != null) result.error("share-interrupted", "Sharing was interrupted.", null);
        // No file deletion: an external consumer may still need its content URI.
    }
}
