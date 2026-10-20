#!/usr/bin/env bash
set -euo pipefail

# ==========================================
# BUZZY RELEASE & AUTO-UPDATE CONFIGURATION
# ==========================================
APP_NAME="Buzzy"
SCHEME="Buzzy"
BUNDLE_ID="com.buzzy.app"
GITHUB_REPO="tuyennq1001/buzzy"
PLIST="Buzzy/Info.plist"
PBXPROJ="Buzzy.xcodeproj/project.pbxproj"
ENTITLEMENTS="Buzzy/Buzzy.entitlements"
APPCAST="appcast.xml"
MIN_SYSTEM_VERSION="13.0"
NOTARY_PROFILE="${NOTARY_PROFILE:-GOX_NOTARY}"
if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    if xcrun notarytool history --keychain-profile "notarytool" >/dev/null 2>&1; then
        NOTARY_PROFILE="notarytool"
    fi
fi

# ==========================================
# CLI COLORS & HELPERS
# ==========================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
fail()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }
step()  { echo -e "\n${BLUE}━━━ Step $1: $2 ━━━${NC}"; }

# ==========================================
# USAGE CHECKS
# ==========================================
if [[ $# -lt 2 ]]; then
    echo "Usage: ./release.sh <version> <build_number>"
    echo "Example: ./release.sh 1.0.0 1"
    echo ""
    echo "  version:       Marketing version (e.g. 1.0.0)"
    echo "  build_number:  Integer build number for Sparkle (e.g. 1)"
    exit 1
fi

VERSION="$1"
BUILD_NUMBER="$2"
TAG="v${VERSION}"
ZIP_NAME="${APP_NAME}.zip"
cd "$(dirname "$0")"

APP_PATH="build/Build/Products/Release/${APP_NAME}.app"

# ==========================================
# 0. PREFLIGHT CHECKS
# ==========================================
step 0 "Preflight checks"

[[ -f "$PLIST" ]]        || fail "Info.plist not found at $PLIST"
[[ -f "$PBXPROJ" ]]      || fail "project.pbxproj not found at $PBXPROJ"
[[ -f "$ENTITLEMENTS" ]] || fail "Entitlements not found at $ENTITLEMENTS"
[[ -f "$APPCAST" ]]      || fail "appcast.xml not found"

command -v xcodebuild >/dev/null || fail "xcodebuild not found"
command -v gh >/dev/null         || fail "GitHub CLI (gh) not found"
command -v git >/dev/null        || fail "git not found"

if git tag -l "$TAG" | grep -qx "$TAG"; then
    fail "Tag $TAG already exists. Bump the version or delete the tag first."
fi

# Locate Sparkle sign_update binary
SPARKLE_SIGN="$(find ./build -name "sign_update" -type f ! -path "*/old_dsa_scripts/*" 2>/dev/null | head -1 || true)"
if [[ -z "$SPARKLE_SIGN" || ! -x "$SPARKLE_SIGN" ]]; then
    SPARKLE_SIGN="/Users/tuyennq1001/htdocs/projects/stockdeck/.build/artifacts/sparkle/Sparkle/bin/sign_update"
fi
if [[ ! -x "$SPARKLE_SIGN" ]]; then
    SPARKLE_SIGN="$(command -v sign_update || true)"
fi

if [[ -n "$SPARKLE_SIGN" && -x "$SPARKLE_SIGN" ]]; then
    info "Found Sparkle sign_update tool at: $SPARKLE_SIGN"
else
    warn "sign_update tool not found yet. It will be searched again after build."
fi

info "Preparing release ${APP_NAME} v${VERSION} (Build ${BUILD_NUMBER})"

# ==========================================
# 1. BUMP VERSION IN PLIST & PBXPROJ
# ==========================================
step 1 "Bump version in Info.plist & project.pbxproj"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "$PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string ${VERSION}" "$PLIST"

/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUMBER}" "$PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string ${BUILD_NUMBER}" "$PLIST"

# Update MARKETING_VERSION and CURRENT_PROJECT_VERSION in project.pbxproj
perl -i -pe "s/MARKETING_VERSION = [^;]+;/MARKETING_VERSION = ${VERSION};/g" "$PBXPROJ"
perl -i -pe "s/CURRENT_PROJECT_VERSION = [^;]+;/CURRENT_PROJECT_VERSION = ${BUILD_NUMBER};/g" "$PBXPROJ"

info "Updated version: CFBundleShortVersionString = ${VERSION}, CFBundleVersion = ${BUILD_NUMBER}"

# ==========================================
# 2. BUILD RELEASE
# ==========================================
step 2 "Build Release with xcodebuild"

xcodebuild -scheme "$SCHEME" -configuration Release -derivedDataPath ./build build

[[ -d "$APP_PATH" ]] || fail "Build failed: $APP_PATH not found"
BINARY="${APP_PATH}/Contents/MacOS/${APP_NAME}"
[[ -f "$BINARY" ]]   || fail "Binary not found at $BINARY"

# Ensure Sparkle.framework is embedded inside Contents/Frameworks
if [[ ! -d "$APP_PATH/Contents/Frameworks/Sparkle.framework" ]]; then
    info "Embedding Sparkle.framework into ${APP_PATH}/Contents/Frameworks"
    mkdir -p "$APP_PATH/Contents/Frameworks"
    SPARKLE_FW="$(find ./build -name "Sparkle.framework" -type d 2>/dev/null | head -1 || true)"
    if [[ -d "$SPARKLE_FW" ]]; then
        cp -R "$SPARKLE_FW" "$APP_PATH/Contents/Frameworks/"
    else
        fail "Could not find Sparkle.framework to embed"
    fi
fi

# Ensure rpath points to Frameworks
install_name_tool -add_rpath "@executable_path/../Frameworks" "$BINARY" 2>/dev/null || true

info "Release build succeeded: $APP_PATH"

# ==========================================
# 3. SMOKE TEST (LAUNCH -> 3S -> CHECK ALIVE)
# ==========================================
step 3 "Smoke test (launch -> 3s -> check alive)"

pkill -9 -f "$APP_PATH/Contents/MacOS/${APP_NAME}" 2>/dev/null || true
open -g "$APP_PATH"
sleep 3

if pgrep -f "$APP_PATH/Contents/MacOS/${APP_NAME}" >/dev/null; then
    pkill -9 -f "$APP_PATH/Contents/MacOS/${APP_NAME}" 2>/dev/null || true
    info "Smoke test passed: App launched and remained stable for 3 seconds."
else
    fail "App crashed during smoke test — aborting release."
fi

# ==========================================
# 4. CODE-SIGNING
# ==========================================
step 4 "Code-sign Application"

HAS_DEV_ID=false
DEV_ID_IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | awk -F'"' '{print $2}' || true)
APPLE_DEV_IDENTITY=$(security find-identity -v -p codesigning | grep "Apple Development" | head -1 | awk -F'"' '{print $2}' || true)

if [[ -n "$DEV_ID_IDENTITY" ]]; then
    info "Code-signing with Developer ID: $DEV_ID_IDENTITY"

    # Clean up internal dependency zip archives (e.g. LaunchAtLoginHelper.zip) that fail Apple Notarization
    find "$APP_PATH" -name "*.zip" -delete
    find "$APP_PATH" -name "copy-helper-swiftpm.sh" -delete
    
    # 1. Sign embedded frameworks
    if [[ -d "$APP_PATH/Contents/Frameworks" ]]; then
        find "$APP_PATH/Contents/Frameworks" -type d -name "*.framework" | while read -r fw; do
            codesign --deep --force --verify --verbose --sign "$DEV_ID_IDENTITY" --options runtime --timestamp "$fw"
        done
    fi

    # 2. Sign Login Item Helper if present
    LOGIN_HELPER="$APP_PATH/Contents/Library/LoginItems/LaunchAtLoginHelper.app"
    if [[ -d "$LOGIN_HELPER" ]]; then
        codesign --deep --force --verify --verbose --sign "$DEV_ID_IDENTITY" --options runtime --timestamp "$LOGIN_HELPER"
    fi

    # 3. Sign resource bundles if present
    if [[ -d "$APP_PATH/Contents/Resources" ]]; then
        find "$APP_PATH/Contents/Resources" -type d -name "*.bundle" | while read -r bndl; do
            codesign --force --sign "$DEV_ID_IDENTITY" --timestamp "$bndl" 2>/dev/null || true
        done
    fi

    # 4. Sign main .app bundle
    codesign --force --verify --verbose \
        --sign "$DEV_ID_IDENTITY" \
        --entitlements "$ENTITLEMENTS" \
        --options runtime \
        --timestamp \
        "$APP_PATH"

    codesign --verify --deep --strict "$APP_PATH" || fail "Code-sign verification failed"
    HAS_DEV_ID=true
    info "Successfully signed and verified with Developer ID"
elif [[ -n "$APPLE_DEV_IDENTITY" ]]; then
    warn "Developer ID not found. Using Apple Development identity ($APPLE_DEV_IDENTITY)."
    codesign --deep --force --sign "$APPLE_DEV_IDENTITY" "$APP_PATH"
    info "Signed with Apple Development identity"
else
    warn "Developer ID not found. Using ad-hoc signature."
    codesign --deep --force --sign - "$APP_PATH"
    info "Signed with ad-hoc signature"
fi

# ==========================================
# 5. PACKAGE ZIP
# ==========================================
step 5 "Package ZIP archive"

rm -f "$ZIP_NAME"
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_NAME"
ZIP_SIZE=$(stat -f%z "$ZIP_NAME")
info "Created $ZIP_NAME ($ZIP_SIZE bytes)"

# ==========================================
# 6. APPLE NOTARIZATION & STAPLE (IF CONFIGURED)
# ==========================================
if [[ "$HAS_DEV_ID" == "true" ]]; then
    step 6 "Apple Notarization & Stapling"
    if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
        info "Submitting $ZIP_NAME to Apple Notary Service..."
        SUBMIT_OUTPUT=$(xcrun notarytool submit "$ZIP_NAME" --keychain-profile "$NOTARY_PROFILE" --wait 2>&1 || true)
        echo "$SUBMIT_OUTPUT"
        
        if echo "$SUBMIT_OUTPUT" | grep -q "status: Accepted"; then
            info "Notarization accepted. Stapling ticket to .app..."
            xcrun stapler staple "$APP_PATH"
            
            # Re-package ZIP with stapled ticket
            rm -f "$ZIP_NAME"
            ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_NAME"
            ZIP_SIZE=$(stat -f%z "$ZIP_NAME")
            info "Re-packaged $ZIP_NAME with stapled ticket ($ZIP_SIZE bytes)"
        else
            SUBMISSION_ID=$(echo "$SUBMIT_OUTPUT" | grep -oE "id: [a-f0-9-]+" | head -1 | awk '{print $2}' || true)
            if [[ -n "$SUBMISSION_ID" ]]; then
                warn "Notarization failed. Fetching log for $SUBMISSION_ID:"
                xcrun notarytool log "$SUBMISSION_ID" --keychain-profile "$NOTARY_PROFILE" || true
            fi
            fail "Apple Notarization failed — aborting release."
        fi
    else
        warn "Notary profile '$NOTARY_PROFILE' not configured in keychain. Skipping notarization."
    fi
else
    warn "Skipping notarization (requires Developer ID certificate)."
fi

# ==========================================
# 7. SPARKLE EdDSA SIGNATURE
# ==========================================
step 7 "Sparkle EdDSA Sign"

if [[ -z "$SPARKLE_SIGN" || ! -x "$SPARKLE_SIGN" ]]; then
    SPARKLE_SIGN="$(find ./build -name "sign_update" -type f ! -path "*/old_dsa_scripts/*" 2>/dev/null | head -1 || true)"
fi

if [[ -n "$SPARKLE_SIGN" && -x "$SPARKLE_SIGN" ]] && SIGN_OUTPUT=$("$SPARKLE_SIGN" "$ZIP_NAME" 2>&1); then
    ED_SIGNATURE=$(echo "$SIGN_OUTPUT" | grep -oE 'sparkle:edSignature="[^"]+"' | cut -d'"' -f2 || true)
    if [[ -z "$ED_SIGNATURE" ]]; then
        ED_SIGNATURE="$SIGN_OUTPUT"
    fi
    info "Generated edSignature: $ED_SIGNATURE"
else
    warn "Sparkle key or sign_update tool not found. Update might fail verification."
    ED_SIGNATURE="NOSIGNATURE"
fi

# ==========================================
# 8. UPDATE APPCAST.XML
# ==========================================
step 8 "Update appcast.xml"

PUBDATE=$(date -R)
DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/download/${TAG}/${ZIP_NAME}"
NOTES_FILE="release-notes/${VERSION}.html"

if [[ -f "$NOTES_FILE" ]]; then
    DESCRIPTION_BLOCK="<description><![CDATA[$(cat "$NOTES_FILE")]]></description>"
    info "Loaded release notes from $NOTES_FILE"
else
    DESCRIPTION_BLOCK="<description>Version ${VERSION}</description>"
    warn "No release notes found at $NOTES_FILE — using placeholder"
fi

cat > "$APPCAST" <<APPCAST_EOF
<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/" version="2.0">
    <channel>
        <title>${APP_NAME}</title>
        <link>https://github.com/${GITHUB_REPO}</link>
        <description>${APP_NAME} Pomodoro update feed</description>
        <language>en</language>
        <item>
            <title>Version ${VERSION}</title>
            <pubDate>${PUBDATE}</pubDate>
            <sparkle:version>${BUILD_NUMBER}</sparkle:version>
            <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>${MIN_SYSTEM_VERSION}</sparkle:minimumSystemVersion>
            ${DESCRIPTION_BLOCK}
            <enclosure url="${DOWNLOAD_URL}"
                       type="application/octet-stream"
                       sparkle:edSignature="${ED_SIGNATURE}"
                       length="${ZIP_SIZE}"/>
        </item>
    </channel>
</rss>
APPCAST_EOF

info "Updated appcast.xml"

# ==========================================
# 9. COMMIT, PUSH & GITHUB RELEASE
# ==========================================
step 9 "Commit, Push & GitHub Release"

git add "$PLIST" "$PBXPROJ" "$ENTITLEMENTS" "$APPCAST" release.sh
if [[ -f "$NOTES_FILE" ]]; then
    git add "$NOTES_FILE"
fi

git commit -m "chore(release): v${VERSION} (build ${BUILD_NUMBER})" || true

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
git push -u origin "$CURRENT_BRANCH"

GH_NOTES_FILE="$(mktemp)"
if [[ -f "$NOTES_FILE" ]]; then
    perl -0pe 's{<style.*?</style>}{}gs; s{<h2>(.*?)</h2>}{## $1\n}gs; s{<h3>(.*?)</h3>}{\n### $1\n}gs; s{<li>(.*?)</li>}{- $1\n}gs; s{</?ul>}{}gs; s{<b>(.*?)</b>}{**$1**}gs; s{<strong>(.*?)</strong>}{**$1**}gs; s{<[^>]+>}{}gs; s{&amp;}{&}g; s{&lt;}{<}g; s{&gt;}{>}g; s{^[ \t]+}{}mg' "$NOTES_FILE" | cat -s > "$GH_NOTES_FILE"
else
    echo "Buzzy Version ${VERSION}" > "$GH_NOTES_FILE"
fi

PREV_TAG="$(gh release view --repo "$GITHUB_REPO" --json tagName -q .tagName 2>/dev/null || true)"
if [[ -n "$PREV_TAG" ]]; then
    printf '\n\n**Full Changelog**: https://github.com/%s/compare/%s...%s\n' "$GITHUB_REPO" "$PREV_TAG" "$TAG" >> "$GH_NOTES_FILE"
fi

gh release create "$TAG" "$ZIP_NAME" \
    --repo "$GITHUB_REPO" \
    --title "${APP_NAME} v${VERSION}" \
    --notes-file "$GH_NOTES_FILE"

rm -f "$GH_NOTES_FILE" "$ZIP_NAME"

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  ${APP_NAME} v${VERSION} (build ${BUILD_NUMBER}) released successfully!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  GitHub Release: https://github.com/${GITHUB_REPO}/releases/tag/${TAG}"
echo "  Appcast Feed:   https://raw.githubusercontent.com/${GITHUB_REPO}/main/appcast.xml"
echo ""
