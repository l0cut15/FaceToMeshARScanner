# Camera Permissions Setup Guide

## ⚠️ CRITICAL: Add Camera Permission to Info.plist

Your app is crashing/halting because it's missing the required camera privacy permission.

## How to Fix in Xcode:

### Method 1: Using Info.plist Editor (Easiest)

1. Open your project in Xcode
2. Select your project in the navigator
3. Select your target (FaceScanner)
4. Go to the **Info** tab
5. Click the **+** button to add a new key
6. Type: `Privacy - Camera Usage Description`
7. Set the value to: `FaceScanner needs camera access to capture 3D face scans for 3D printing.`

### Method 2: Edit Info.plist as Source Code

1. Right-click on `Info.plist` in Xcode
2. Choose **Open As > Source Code**
3. Add this inside the `<dict>` tag:

```xml
<key>NSCameraUsageDescription</key>
<string>FaceScanner needs camera access to capture 3D face scans for 3D printing.</string>
```

### Complete Info.plist Example:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>$(DEVELOPMENT_LANGUAGE)</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>$(PRODUCT_BUNDLE_PACKAGE_TYPE)</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    
    <!-- ⭐ ADD THIS LINE ⭐ -->
    <key>NSCameraUsageDescription</key>
    <string>FaceScanner needs camera access to capture 3D face scans for 3D printing.</string>
    
    <key>UILaunchStoryboardName</key>
    <string>LaunchScreen</string>
</dict>
</plist>
```

## Why This is Required:

- **iOS Security:** All apps must declare why they need camera access
- **Without it:** iOS will terminate your app immediately when accessing the camera
- **User Experience:** Users see a permission dialog with your message

## After Adding:

1. **Clean Build Folder:** Product → Clean Build Folder (⇧⌘K)
2. **Rebuild:** Product → Build (⌘B)
3. **Run on Device:** The first time, iOS will show a permission dialog
4. **Grant Permission:** Tap "OK" to allow camera access

## Testing:

- First launch: You'll see a system permission dialog
- If denied: Go to Settings → FaceScanner → Camera → Enable
- If still issues: Delete the app and reinstall

## Troubleshooting:

### "Still crashing after adding permission"
- Make sure you cleaned and rebuilt
- Check the Console for error messages
- Verify the key name is exactly: `NSCameraUsageDescription`

### "Permission dialog not showing"
- Check Settings → FaceScanner → Camera
- Delete app and reinstall to trigger fresh permission request

### "App just shows black screen"
- Check device has Face ID capability (iPhone X or newer)
- Go to Settings → Privacy → Camera → Enable for FaceScanner

## Additional Permissions (Optional but Recommended):

If you want to save photos/exports to the photo library, also add:

```xml
<key>NSPhotoLibraryAddUsageDescription</key>
<string>Save your 3D face scans to your photo library.</string>
```

---

**After making these changes, your app should work properly!**
