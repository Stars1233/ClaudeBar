#!/bin/bash
# Update appcast.xml with a new release entry
# Usage: ./scripts/update-appcast.sh <version> <build_number> <download_url> <signature> <file_size> [release_notes]

set -e

VERSION="$1"
BUILD_NUMBER="$2"
DOWNLOAD_URL="$3"
ED_SIGNATURE="$4"
FILE_SIZE="$5"
RELEASE_NOTES="${6:-Bug fixes and improvements.}"
PUB_DATE=$(date -R)

mkdir -p docs

# Convert markdown to simple HTML
# Replace **text** with <strong>text</strong>
# Replace - item with <li>item</li>
# Replace ### heading with <h4>heading</h4>
HTML_NOTES=$(echo "$RELEASE_NOTES" | \
    sed 's/\*\*\([^*]*\)\*\*/<strong>\1<\/strong>/g' | \
    sed 's/^- \(.*\)/<li>\1<\/li>/g' | \
    sed 's/^### \(.*\)/<h4>\1<\/h4>/g' | \
    tr '\n' ' ' | \
    sed 's/<\/li> <li>/<\/li><li>/g')

# Wrap list items in <ul> if present
if echo "$HTML_NOTES" | grep -q '<li>'; then
    HTML_NOTES=$(echo "$HTML_NOTES" | sed 's/<li>/<ul><li>/;s/<\/li>\([^<]*\)$/<\/li><\/ul>\1/')
fi

# Create fresh appcast with only the new version
cat > docs/appcast.xml << EOF
<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
    <channel>
        <title>ClaudeBar</title>
        <item>
            <title>${VERSION}</title>
            <pubDate>${PUB_DATE}</pubDate>
            <sparkle:version>${BUILD_NUMBER}</sparkle:version>
            <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
            <description><![CDATA[<h2>ClaudeBar ${VERSION}</h2>
${HTML_NOTES}
<p><a href="https://github.com/tddworks/ClaudeBar/releases/tag/v${VERSION}">View full release notes</a></p>
]]></description>
            <enclosure url="${DOWNLOAD_URL}" length="${FILE_SIZE}" type="application/octet-stream" sparkle:edSignature="${ED_SIGNATURE}"/>
        </item>
    </channel>
</rss>
EOF

echo "Generated appcast.xml:"
cat docs/appcast.xml
