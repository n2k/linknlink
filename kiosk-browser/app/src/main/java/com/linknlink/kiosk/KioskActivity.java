package com.linknlink.kiosk;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.net.http.SslError;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.PowerManager;
import android.util.Log;
import android.view.KeyEvent;
import android.view.View;
import android.view.WindowManager;
import android.webkit.ConsoleMessage;
import android.webkit.SslErrorHandler;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextView;

public class KioskActivity extends Activity {

    private static final String TAG = "KioskBrowser";
    private static final String PREFS_NAME = "kiosk_prefs";
    private static final String PREF_URL = "kiosk_url";
    private static final String DEFAULT_URL = "http://homeassistant.local:8123";

    private static final long RETRY_DELAY_MS = 5000;
    private static final int LONG_PRESS_SETTINGS_DURATION = 5000; // 5 seconds

    private WebView webView;
    private View errorView;
    private FrameLayout rootLayout;
    private Handler handler;
    private PowerManager.WakeLock wakeLock;
    private boolean isShowingError = false;

    // Long-press tracking for settings access
    private int cornerTapCount = 0;
    private long lastCornerTapTime = 0;

    @SuppressLint("SetJavaScriptEnabled")
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        handler = new Handler(Looper.getMainLooper());

        // Keep screen on and fullscreen
        getWindow().addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON |
            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD |
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED |
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
        );

        // Set up layout
        rootLayout = new FrameLayout(this);
        rootLayout.setBackgroundColor(Color.BLACK);

        // Create WebView
        webView = new WebView(this);
        configureWebView();
        rootLayout.addView(webView, new FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        ));

        // Create error view (hidden initially)
        errorView = createErrorView();
        errorView.setVisibility(View.GONE);
        rootLayout.addView(errorView, new FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        ));

        setContentView(rootLayout);

        // Enter immersive mode
        enterImmersiveMode();

        // Acquire wake lock
        PowerManager pm = (PowerManager) getSystemService(Context.POWER_SERVICE);
        wakeLock = pm.newWakeLock(
            PowerManager.SCREEN_BRIGHT_WAKE_LOCK | PowerManager.ACQUIRE_CAUSES_WAKEUP,
            "kiosk:wakelock"
        );
        wakeLock.acquire();

        // Check for URL passed via intent (e.g., from ADB)
        String intentUrl = getIntent().getStringExtra("url");
        if (intentUrl != null && !intentUrl.isEmpty()) {
            saveUrl(intentUrl);
        }

        // Load the configured URL
        loadKioskUrl();

        Log.i(TAG, "Kiosk browser started");
    }

    @SuppressLint("SetJavaScriptEnabled")
    private void configureWebView() {
        WebSettings settings = webView.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setDatabaseEnabled(true);
        settings.setMediaPlaybackRequiresUserGesture(false);
        settings.setCacheMode(WebSettings.LOAD_DEFAULT);
        settings.setMixedContentMode(WebSettings.MIXED_CONTENT_ALWAYS_ALLOW);
        settings.setUseWideViewPort(true);
        settings.setLoadWithOverviewMode(true);
        settings.setSupportZoom(false);
        settings.setBuiltInZoomControls(false);
        settings.setDisplayZoomControls(false);
        settings.setAllowFileAccess(true);
        settings.setAllowContentAccess(true);
        settings.setUserAgentString(settings.getUserAgentString() + " KioskBrowser/1.0");

        webView.setBackgroundColor(Color.BLACK);
        webView.setOverScrollMode(View.OVER_SCROLL_NEVER);

        webView.setWebViewClient(new WebViewClient() {
            private boolean hadError = false;

            @Override
            public void onPageStarted(WebView view, String url, android.graphics.Bitmap favicon) {
                super.onPageStarted(view, url, favicon);
                hadError = false;
            }

            @Override
            public void onPageFinished(WebView view, String url) {
                super.onPageFinished(view, url);
                Log.i(TAG, "Page loaded: " + url);
                if (!hadError) {
                    showWebView();
                }
            }

            @Override
            public void onReceivedError(WebView view, WebResourceRequest request, WebResourceError error) {
                if (request.isForMainFrame()) {
                    hadError = true;
                    Log.e(TAG, "Load error: " + error.getDescription());
                    showError("Connection Error",
                        "Could not load page.\n" + error.getDescription() +
                        "\n\nRetrying in " + (RETRY_DELAY_MS / 1000) + " seconds...");
                    scheduleRetry();
                }
            }

            @SuppressLint("WebViewClientOnReceivedSslError")
            @Override
            public void onReceivedSslError(WebView view, SslErrorHandler handler, SslError error) {
                // Accept self-signed certificates for local HA instances
                Log.w(TAG, "SSL error (accepting): " + error.getUrl());
                handler.proceed();
            }

            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                // Keep all navigation within the WebView
                return false;
            }
        });

        webView.setWebChromeClient(new WebChromeClient() {
            @Override
            public boolean onConsoleMessage(ConsoleMessage consoleMessage) {
                Log.d(TAG, "JS: " + consoleMessage.message() +
                    " (" + consoleMessage.sourceId() + ":" + consoleMessage.lineNumber() + ")");
                return true;
            }
        });
    }

    private View createErrorView() {
        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        layout.setGravity(android.view.Gravity.CENTER);
        layout.setBackgroundColor(Color.parseColor("#1a1a2e"));
        layout.setPadding(80, 80, 80, 80);

        // Title
        TextView title = new TextView(this);
        title.setId(android.R.id.title);
        title.setTextColor(Color.WHITE);
        title.setTextSize(28);
        title.setGravity(android.view.Gravity.CENTER);
        layout.addView(title);

        // Spacer
        View spacer = new View(this);
        LinearLayout.LayoutParams spacerParams = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, 24);
        layout.addView(spacer, spacerParams);

        // Message
        TextView message = new TextView(this);
        message.setId(android.R.id.message);
        message.setTextColor(Color.parseColor("#aaaaaa"));
        message.setTextSize(18);
        message.setGravity(android.view.Gravity.CENTER);
        layout.addView(message);

        return layout;
    }

    private void showError(String title, String message) {
        isShowingError = true;
        runOnUiThread(() -> {
            ((TextView) errorView.findViewById(android.R.id.title)).setText(title);
            ((TextView) errorView.findViewById(android.R.id.message)).setText(message);
            errorView.setVisibility(View.VISIBLE);
            webView.setVisibility(View.INVISIBLE);
        });
    }

    private void showWebView() {
        isShowingError = false;
        runOnUiThread(() -> {
            webView.setVisibility(View.VISIBLE);
            errorView.setVisibility(View.GONE);
        });
    }

    private void scheduleRetry() {
        handler.postDelayed(this::loadKioskUrl, RETRY_DELAY_MS);
    }

    private void loadKioskUrl() {
        String url = getUrl();
        Log.i(TAG, "Loading URL: " + url);

        if (!isNetworkAvailable()) {
            showError("No Network", "Waiting for network connection...\n\nRetrying in " +
                (RETRY_DELAY_MS / 1000) + " seconds...");
            scheduleRetry();
            return;
        }

        webView.loadUrl(url);
    }

    private boolean isNetworkAvailable() {
        ConnectivityManager cm = (ConnectivityManager) getSystemService(Context.CONNECTIVITY_SERVICE);
        if (cm == null) return false;
        Network network = cm.getActiveNetwork();
        if (network == null) return false;
        NetworkCapabilities caps = cm.getNetworkCapabilities(network);
        return caps != null && (
            caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
            caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) ||
            caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR)
        );
    }

    // --- URL persistence ---

    private String getUrl() {
        SharedPreferences prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
        return prefs.getString(PREF_URL, DEFAULT_URL);
    }

    private void saveUrl(String url) {
        SharedPreferences prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
        prefs.edit().putString(PREF_URL, url).apply();
        Log.i(TAG, "URL saved: " + url);
    }

    // --- Immersive mode ---

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        if (hasFocus) {
            enterImmersiveMode();
        }
    }

    private void enterImmersiveMode() {
        getWindow().getDecorView().setSystemUiVisibility(
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY |
            View.SYSTEM_UI_FLAG_FULLSCREEN |
            View.SYSTEM_UI_FLAG_HIDE_NAVIGATION |
            View.SYSTEM_UI_FLAG_LAYOUT_STABLE |
            View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION |
            View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
        );
    }

    // --- Key handling ---

    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        // Back key: go back in WebView history or do nothing
        if (keyCode == KeyEvent.KEYCODE_BACK) {
            if (webView.canGoBack()) {
                webView.goBack();
            }
            return true; // Consume — never exit kiosk
        }
        // Volume Up + Volume Down simultaneously: open settings
        return super.onKeyDown(keyCode, event);
    }

    // --- Settings access: tap top-right corner 5 times rapidly ---

    @Override
    public boolean dispatchTouchEvent(android.view.MotionEvent ev) {
        if (ev.getAction() == android.view.MotionEvent.ACTION_DOWN) {
            float x = ev.getX();
            float y = ev.getY();
            int width = rootLayout.getWidth();

            // Top-right corner (top 80px, right 80px)
            if (x > width - 80 && y < 80) {
                long now = System.currentTimeMillis();
                if (now - lastCornerTapTime > 3000) {
                    cornerTapCount = 0;
                }
                cornerTapCount++;
                lastCornerTapTime = now;

                if (cornerTapCount >= 5) {
                    cornerTapCount = 0;
                    openSettings();
                }
            }
        }
        return super.dispatchTouchEvent(ev);
    }

    private void openSettings() {
        Intent intent = new Intent(this, SettingsActivity.class);
        intent.putExtra("current_url", getUrl());
        startActivityForResult(intent, 1);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == 1 && resultCode == RESULT_OK && data != null) {
            String newUrl = data.getStringExtra("url");
            if (newUrl != null && !newUrl.isEmpty()) {
                saveUrl(newUrl);
                loadKioskUrl();
            }
        }
    }

    // --- Lifecycle ---

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        // Handle new URL from ADB: am start -n com.linknlink.kiosk/.KioskActivity --es url "http://..."
        String url = intent.getStringExtra("url");
        if (url != null && !url.isEmpty()) {
            saveUrl(url);
            loadKioskUrl();
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        enterImmersiveMode();
        webView.onResume();
    }

    @Override
    protected void onPause() {
        super.onPause();
        webView.onPause();
    }

    @Override
    protected void onDestroy() {
        handler.removeCallbacksAndMessages(null);
        if (wakeLock != null && wakeLock.isHeld()) {
            wakeLock.release();
        }
        webView.destroy();
        super.onDestroy();
    }
}
