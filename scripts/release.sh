#!/bin/zsh

# リリースビルドスクリプト
#
# ビルド → .app 公証 → DMG 作成 → DMG 公証 → appcast.xml 更新 をワンコマンドで実行する
#
# 使い方:
#   ./scripts/release.sh                              # AppVersion.plist のバージョンでビルド
#   VERSION=0.3.0 ./scripts/release.sh                # バージョンを上書き（plist も更新）
#   VERSION=0.3.0 BUILD_NUMBER=3 ./scripts/release.sh # バージョン + ビルド番号を上書き
#
# 出力先:
#   dist/v<VERSION>/CuotaBar.app
#   dist/v<VERSION>/CuotaBar.dmg

set -euo pipefail

APP_NAME="CuotaBar"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION_PLIST="$ROOT_DIR/CuotaBar/Sources/CuotaBar/Resources/AppVersion.plist"
APPCAST="$ROOT_DIR/docs/appcast.xml"
SIGN_UPDATE="$ROOT_DIR/.build/artifacts/sparkle/Sparkle/bin/sign_update"
GITHUB_RELEASE_BASE="${GITHUB_RELEASE_BASE:-}"

if [[ -z "${SIGN_IDENTITY:-}" || "$SIGN_IDENTITY" == "-" ]]; then
  echo "Set SIGN_IDENTITY to your Developer ID Application certificate." >&2
  exit 1
fi

if [[ -n "${UPDATE_FEED_URL:-}${UPDATE_PUBLIC_KEY:-}" ]]; then
  if [[ "${UPDATE_FEED_URL:-}" != https://?* || -z "${UPDATE_PUBLIC_KEY:-}" || "$GITHUB_RELEASE_BASE" != https://?* ]]; then
    echo "Set UPDATE_FEED_URL and GITHUB_RELEASE_BASE to HTTPS URLs and provide UPDATE_PUBLIC_KEY." >&2
    exit 1
  fi
fi

DEFAULT_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :MarketingVersion' "$VERSION_PLIST")"
DEFAULT_BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :BuildNumber' "$VERSION_PLIST")"
VERSION="${VERSION:-$DEFAULT_VERSION}"
BUILD_NUMBER="${BUILD_NUMBER:-$DEFAULT_BUILD_NUMBER}"
export VERSION BUILD_NUMBER

DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist/v$VERSION}"
export DIST_DIR

echo "==> Release v$VERSION (build $BUILD_NUMBER)"
echo "    出力先: $DIST_DIR"
echo ""

# AppVersion.plist を更新（上書き指定時のみ）
if [[ "$VERSION" != "$DEFAULT_VERSION" || "$BUILD_NUMBER" != "$DEFAULT_BUILD_NUMBER" ]]; then
  echo "==> AppVersion.plist を更新"
  /usr/libexec/PlistBuddy -c "Set :MarketingVersion $VERSION" "$VERSION_PLIST"
  /usr/libexec/PlistBuddy -c "Set :BuildNumber $BUILD_NUMBER" "$VERSION_PLIST"
fi

# 1. ビルド
"$ROOT_DIR/scripts/build_app.sh"

# 2. .app 公証
TARGET="$DIST_DIR/$APP_NAME.app" "$ROOT_DIR/scripts/notarize.sh"

# 3. DMG 作成 + 公証
"$ROOT_DIR/scripts/build_dmg.sh"

# 4. appcast.xml 更新
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"

if [[ -z "${UPDATE_FEED_URL:-}" ]]; then
  echo "Automatic updates are not configured; skipping appcast generation."
elif [[ ! -f "$SIGN_UPDATE" ]]; then
  echo "WARNING: sign_update が見つかりません。appcast.xml の edSignature は手動で更新してください。" >&2
else
  echo "==> appcast.xml を更新"

  DMG_LENGTH="$(stat -f %z "$DMG_PATH")"
  ED_SIGNATURE="$("$SIGN_UPDATE" "$DMG_PATH" 2>/dev/null | grep -o 'sparkle:edSignature="[^"]*"' | cut -d'"' -f2)"
  PUB_DATE="$(date -u '+%a, %d %b %Y %H:%M:%S +0000')"
  ENCLOSURE_URL="$GITHUB_RELEASE_BASE/v$VERSION/$APP_NAME.dmg"

  cat > "$APPCAST" <<XML
<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
    <channel>
        <title>$APP_NAME</title>
        <item>
            <title>$VERSION</title>
            <pubDate>$PUB_DATE</pubDate>
            <sparkle:version>$BUILD_NUMBER</sparkle:version>
            <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
            <enclosure url="$ENCLOSURE_URL" length="$DMG_LENGTH" type="application/octet-stream" sparkle:edSignature="$ED_SIGNATURE"/>
        </item>
    </channel>
</rss>
XML

  # dist/ 以下にも同期
  cp "$APPCAST" "$ROOT_DIR/dist/appcast.xml"

  echo "    appcast.xml 更新完了"
  echo "    url:          $ENCLOSURE_URL"
  echo "    length:       $DMG_LENGTH"
  echo "    edSignature:  $ED_SIGNATURE"
fi

echo ""
echo "==> Release complete: $DIST_DIR"
echo "    $APP_NAME.app"
echo "    $APP_NAME.dmg"
echo ""
echo "次のステップ:"
if [[ -n "$GITHUB_RELEASE_BASE" ]]; then
  echo "  Upload the DMG to: $GITHUB_RELEASE_BASE/v$VERSION/$APP_NAME.dmg"
  if [[ -n "${UPDATE_FEED_URL:-}" ]]; then
    echo "  Publish docs/appcast.xml at your update feed URL."
  fi
fi
