package com.zig.helloworld;

import android.app.Activity;
import android.os.Bundle;
import android.util.Log;

public class MainActivity extends Activity {
    static {
        Log.d("ZigHelloWorld", "Static block: About to load native library");
        try {
            System.loadLibrary("helloworld");
            Log.d("ZigHelloWorld", "Static block: Native library loaded successfully");
        } catch (UnsatisfiedLinkError e) {
            Log.e("ZigHelloWorld", "Static block: Failed to load native library", e);
        }
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        Log.d("ZigHelloWorld", "onCreate: Starting");
        super.onCreate(savedInstanceState);
        Log.d("ZigHelloWorld", "onCreate: About to call initializeFromNative");
        try {
            initializeFromNative();
            Log.d("ZigHelloWorld", "onCreate: initializeFromNative returned successfully");
        } catch (UnsatisfiedLinkError e) {
            Log.e("ZigHelloWorld", "onCreate: UnsatisfiedLinkError calling initializeFromNative", e);
        } catch (Exception e) {
            Log.e("ZigHelloWorld", "onCreate: Exception calling initializeFromNative", e);
        }
        Log.d("ZigHelloWorld", "onCreate: Complete");
    }

    public native void initializeFromNative();
}