#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# BUZZY - MAC APP STORE PACKAGING & SUBMISSION SCRIPT
# Prepares, builds, sandboxes, signs and packages Buzzy for the Mac App Store
# ==============================================================================

APP_NAME="Buzzy"
SCHEME="Buzzy"
BUNDLE_ID="com.buzzy.focus"
PLIST="Buzzy/Info.plist"
PBXPROJ="Buzzy.xcodeproj/project.pbxproj"
ENTITLEMENTS="Buzzy/BuzzyAppStore.entitlements"
BUILD_DIR="./build-appstore"
MIN_SYSTEM_VERSION="13.0"

# CLI Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
fail()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }
step()  { echo -e "\n${BLUE}━━━ Step $1: $2 ━━━${NC}"; }

cd "$(dirname "$0")"

# Version extraction or arguments
if [[ $# -ge 2 ]]; then
    VERSION="$1"
    BUILD_NUMBER="$2"
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "$PLIST" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string ${VERSION}" "$PLIST"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUMBER}" "$PLIST" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string ${BUILD_NUMBER}" "$PLIST"
else
    VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST" 2>/dev/null || echo "1.0.2")
    BUILD_NUMBER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$PLIST" 2>/dev/null || echo "3")
fi

PKG_NAME="${APP_NAME}_v${VERSION}_b${BUILD_NUMBER}_MAS.pkg"
PKG_PATH="${BUILD_DIR}/${PKG_NAME}"
APP_PATH="${BUILD_DIR}/Build/Products/Release/${APP_NAME}.app"

# ==========================================
# 0. PREFLIGHT CHECKS
# ==========================================
step 0 "Preflight Checks"

[[ -f "$PLIST" ]]        || fail "Info.plist not found at $PLIST"
[[ -f "$PBXPROJ" ]]      || fail "project.pbxproj not found at $PBXPROJ"
[[ -f "$ENTITLEMENTS" ]] || fail "App Store Entitlements not found at $ENTITLEMENTS"

command -v xcodebuild   >/dev/null || fail "xcodebuild not found"
command -v productbuild >/dev/null || fail "productbuild not found"
command -v codesign     >/dev/null || fail "codesign not found"

APP_CERT=$(security find-identity -v -p codesigning | grep "3rd Party Mac Developer Application" | head -1 | awk -F'"' '{print $2}' || true)
INSTALLER_CERT=$(security find-identity -v | grep "3rd Party Mac Developer Installer" | head -1 | awk -F'"' '{print $2}' || true)

if [[ -z "$APP_CERT" ]]; then
    fail "Certificate '3rd Party Mac Developer Application' not found in Keychain. Please import it first."
fi
if [[ -z "$INSTALLER_CERT" ]]; then
    fail "Certificate '3rd Party Mac Developer Installer' not found in Keychain. Please import it first."
fi

info "Found App Signing Cert:       $APP_CERT"
info "Found Installer Signing Cert: $INSTALLER_CERT"
info "Building ${APP_NAME} v${VERSION} (Build ${BUILD_NUMBER}) for Mac App Store..."

# ==========================================
# 1. COMPILE WITH APP_STORE FLAG & SANDBOX
# ==========================================
step 1 "Compile with APP_STORE flag & Sandboxed Entitlements"

mkdir -p "$BUILD_DIR"

xcodebuild -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    SWIFT_ACTIVE_COMPILATION_CONDITIONS="APP_STORE" \
    CODE_SIGN_ENTITLEMENTS="$ENTITLEMENTS" \
    OTHER_LDFLAGS='$(inherited) -Wl,-dead_strip_dylibs' \
    build

[[ -d "$APP_PATH" ]] || fail "Build failed, app bundle not found at $APP_PATH"
info "Build completed successfully."

# ==========================================
# 2. STRIP FORBIDDEN STORE COMPONENTS
# ==========================================
step 2 "Strip Store-Forbidden Components & Clean Bundle"

# Remove Sparkle framework if embedded (strictly forbidden in Mac App Store)
if [[ -d "$APP_PATH/Contents/Frameworks/Sparkle.framework" ]]; then
    rm -rf "$APP_PATH/Contents/Frameworks/Sparkle.framework"
    info "Removed Sparkle.framework from bundle."
fi

# Clean up helper archives and scripts
rm -rf "$APP_PATH/Contents/Library/LoginItems"
find "$APP_PATH" -name "*.zip" -delete 2>/dev/null || true
find "$APP_PATH" -name "copy-helper-swiftpm.sh" -delete 2>/dev/null || true

# Strip Sparkle keys from compiled Info.plist
BUILT_PLIST="$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Delete :SUAutomaticallyUpdate" "$BUILT_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Delete :SUEnableAutomaticChecks" "$BUILT_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Delete :SUFeedURL" "$BUILT_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Delete :SUPublicEDKey" "$BUILT_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Delete :SUScheduledCheckInterval" "$BUILT_PLIST" 2>/dev/null || true

info "Bundle cleaned and Sparkle metadata stripped."

# ==========================================
# 3. CODE SIGN WITH 3RD PARTY DEVELOPER APP
# ==========================================
step 3 "Code-sign App with 3rd Party Mac Developer Application & Sandbox"

# Sign embedded resource bundles if any
if [[ -d "$APP_PATH/Contents/Resources" ]]; then
    find "$APP_PATH/Contents/Resources" -type d -name "*.bundle" | while read -r bndl; do
        codesign --force --sign "$APP_CERT" --timestamp "$bndl" 2>/dev/null || true
    done
fi

# Sign main application bundle with Sandbox entitlements
codesign --force \
    --options runtime \
    --entitlements "$ENTITLEMENTS" \
    --sign "$APP_CERT" \
    --timestamp \
    "$APP_PATH"

info "App bundle signed successfully."

# Verify signature
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
info "Signature strictly verified."

# ==========================================
# 4. PACKAGE INTO .PKG WITH INSTALLER CERT
# ==========================================
step 4 "Package into Signed .pkg with 3rd Party Mac Developer Installer"

productbuild --component "$APP_PATH" /Applications \
    --sign "$INSTALLER_CERT" \
    "$PKG_PATH"

[[ -f "$PKG_PATH" ]] || fail "Failed to generate $PKG_PATH"
info "Package created: $PKG_PATH"

# Verify .pkg signature
pkgutil --check-signature "$PKG_PATH"
info "Package signature verified."

# ==========================================
# 5. SUBMISSION GUIDANCE
# ==========================================
step 5 "Mac App Store Upload Ready!"

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Hoàn tất đóng gói bản Mac App Store:${NC} ${PKG_PATH}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Bạn có thể tải gói này lên App Store Connect bằng 1 trong 2 cách:"
echo ""
echo "1. DÙNG ỨNG DỤNG TRANSPORTER (Giao diện trực quan - Khuyên dùng):"
echo "   - Tải 'Transporter' miễn phí từ Mac App Store."
echo "   - Mở Transporter và đăng nhập Apple ID."
echo "   - Kéo thả tệp sau vào Transporter và bấm 'Gửi (Deliver)':"
echo "     👉 $PKG_PATH"
echo ""
echo "2. DÙNG DÒNG LỆNH (xcrun altool):"
echo "   xcrun altool --validate-app -f \"$PKG_PATH\" -t macos -u \"<Apple-ID>\" -p \"<App-Specific-Password>\""
echo "   xcrun altool --upload-app   -f \"$PKG_PATH\" -t macos -u \"<Apple-ID>\" -p \"<App-Specific-Password>\""
echo ""
