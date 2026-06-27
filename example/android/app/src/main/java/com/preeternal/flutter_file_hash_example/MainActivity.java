package com.preeternal.flutter_file_hash_example;

import android.app.Activity;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.provider.OpenableColumns;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import java.util.HashMap;
import java.util.Map;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "flutter_file_hash_example/file_picker";
    private static final int REQUEST_PICK_FILE = 9001;

    private MethodChannel.Result pendingPickResult;

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(
            flutterEngine.getDartExecutor().getBinaryMessenger(),
            CHANNEL
        ).setMethodCallHandler((call, result) -> {
            if ("pickFile".equals(call.method)) {
                pickFile(result);
            } else {
                result.notImplemented();
            }
        });
    }

    @SuppressWarnings("deprecation")
    private void pickFile(MethodChannel.Result result) {
        if (pendingPickResult != null) {
            result.error("picker_busy", "A file picker is already open.", null);
            return;
        }

        pendingPickResult = result;
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType("*/*");
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        intent.addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);

        try {
            startActivityForResult(intent, REQUEST_PICK_FILE);
        } catch (Exception error) {
            pendingPickResult = null;
            result.error(
                "picker_unavailable",
                error.getMessage() != null
                    ? error.getMessage()
                    : "Android file picker is unavailable.",
                null
            );
        }
    }

    @Override
    @Deprecated
    protected void onActivityResult(
        int requestCode,
        int resultCode,
        Intent data
    ) {
        if (requestCode != REQUEST_PICK_FILE) {
            super.onActivityResult(requestCode, resultCode, data);
            return;
        }

        MethodChannel.Result result = pendingPickResult;
        pendingPickResult = null;
        if (result == null) {
            return;
        }

        if (resultCode != Activity.RESULT_OK) {
            result.success(null);
            return;
        }

        Uri uri = data == null ? null : data.getData();
        if (uri == null) {
            result.error("picker_failed", "Android file picker returned no URI.", null);
            return;
        }

        persistReadPermission(uri, data);
        Map<String, Object> payload = new HashMap<>();
        payload.put("uri", uri.toString());
        payload.put("name", displayName(uri));
        payload.put("size", querySize(uri));
        result.success(payload);
    }

    private void persistReadPermission(Uri uri, Intent data) {
        if (data == null) {
            return;
        }

        int readFlags = data.getFlags() & Intent.FLAG_GRANT_READ_URI_PERMISSION;
        if (readFlags == 0) {
            return;
        }

        try {
            getContentResolver().takePersistableUriPermission(uri, readFlags);
        } catch (SecurityException ignored) {
            // Some providers grant transient access only; hashing still works immediately.
        }
    }

    private String displayName(Uri uri) {
        String displayName = queryDisplayName(uri);
        if (displayName != null && !displayName.isEmpty()) {
            return displayName;
        }

        String lastPathSegment = uri.getLastPathSegment();
        return lastPathSegment == null || lastPathSegment.isEmpty()
            ? uri.toString()
            : lastPathSegment;
    }

    private String queryDisplayName(Uri uri) {
        try (Cursor cursor = getContentResolver().query(
            uri,
            new String[] {OpenableColumns.DISPLAY_NAME},
            null,
            null,
            null
        )) {
            if (cursor == null || !cursor.moveToFirst()) {
                return null;
            }

            int index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME);
            return index < 0 || cursor.isNull(index) ? null : cursor.getString(index);
        }
    }

    private long querySize(Uri uri) {
        try (Cursor cursor = getContentResolver().query(
            uri,
            new String[] {OpenableColumns.SIZE},
            null,
            null,
            null
        )) {
            if (cursor == null || !cursor.moveToFirst()) {
                return -1L;
            }

            int index = cursor.getColumnIndex(OpenableColumns.SIZE);
            return index < 0 || cursor.isNull(index) ? -1L : cursor.getLong(index);
        }
    }
}
