package com.linknlink.kiosk;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Color;
import android.os.Build;
import android.os.Bundle;
import android.view.Gravity;
import android.view.View;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.TextView;

public class SettingsActivity extends Activity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Keep fullscreen
        getWindow().getDecorView().setSystemUiVisibility(
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY |
            View.SYSTEM_UI_FLAG_FULLSCREEN |
            View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
        );

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setGravity(Gravity.CENTER);
        root.setBackgroundColor(Color.parseColor("#1a1a2e"));
        root.setPadding(120, 60, 120, 60);

        // Title
        TextView title = new TextView(this);
        title.setText("Kiosk Settings");
        title.setTextColor(Color.WHITE);
        title.setTextSize(32);
        title.setGravity(Gravity.CENTER);
        root.addView(title);

        addSpacer(root, 40);

        // URL Label
        TextView urlLabel = new TextView(this);
        urlLabel.setText("Kiosk URL:");
        urlLabel.setTextColor(Color.parseColor("#cccccc"));
        urlLabel.setTextSize(18);
        root.addView(urlLabel);

        addSpacer(root, 12);

        // URL Input
        EditText urlInput = new EditText(this);
        urlInput.setTextColor(Color.WHITE);
        urlInput.setHintTextColor(Color.parseColor("#666666"));
        urlInput.setBackgroundColor(Color.parseColor("#2a2a4e"));
        urlInput.setPadding(32, 24, 32, 24);
        urlInput.setTextSize(18);
        urlInput.setSingleLine(true);
        urlInput.setHint("http://homeassistant.local:8123");

        String currentUrl = getIntent().getStringExtra("current_url");
        if (currentUrl != null) {
            urlInput.setText(currentUrl);
        }
        root.addView(urlInput, new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        ));

        addSpacer(root, 8);

        // Hint
        TextView hint = new TextView(this);
        hint.setText("You can also set the URL via ADB:\nadb shell am start -n com.linknlink.kiosk/.KioskActivity --es url \"http://your-url\"");
        hint.setTextColor(Color.parseColor("#666666"));
        hint.setTextSize(12);
        root.addView(hint);

        addSpacer(root, 40);

        // Buttons row
        LinearLayout buttons = new LinearLayout(this);
        buttons.setOrientation(LinearLayout.HORIZONTAL);
        buttons.setGravity(Gravity.CENTER);

        // Save button
        Button saveBtn = new Button(this);
        saveBtn.setText("Save & Reload");
        saveBtn.setBackgroundColor(Color.parseColor("#0d7377"));
        saveBtn.setTextColor(Color.WHITE);
        saveBtn.setPadding(60, 24, 60, 24);
        saveBtn.setOnClickListener(v -> {
            String url = urlInput.getText().toString().trim();
            if (!url.isEmpty()) {
                Intent result = new Intent();
                result.putExtra("url", url);
                setResult(RESULT_OK, result);
                finish();
            }
        });
        buttons.addView(saveBtn);

        // Spacer between buttons
        View btnSpacer = new View(this);
        buttons.addView(btnSpacer, new LinearLayout.LayoutParams(40, 1));

        // Cancel button
        Button cancelBtn = new Button(this);
        cancelBtn.setText("Cancel");
        cancelBtn.setBackgroundColor(Color.parseColor("#444444"));
        cancelBtn.setTextColor(Color.WHITE);
        cancelBtn.setPadding(60, 24, 60, 24);
        cancelBtn.setOnClickListener(v -> {
            setResult(RESULT_CANCELED);
            finish();
        });
        buttons.addView(cancelBtn);

        root.addView(buttons);

        addSpacer(root, 40);

        // Device info
        TextView info = new TextView(this);
        info.setText("Device: " + Build.MODEL + " | Android " + Build.VERSION.RELEASE +
            " | Kiosk Browser v1.0.0");
        info.setTextColor(Color.parseColor("#444444"));
        info.setTextSize(12);
        info.setGravity(Gravity.CENTER);
        root.addView(info);

        setContentView(root);
    }

    private void addSpacer(LinearLayout parent, int height) {
        View spacer = new View(this);
        parent.addView(spacer, new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, height));
    }
}
