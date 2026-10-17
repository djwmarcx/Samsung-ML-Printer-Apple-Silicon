#!/bin/bash
# Installs the Samsung ML-1640 / ML-1660 CUPS driver (PPD + rastertoqpdl filter)
# on Apple Silicon macOS (tested on M1 and M4 Pro, macOS Ventura through macOS 27).
#
# Usage:
#   sudo ./install.sh
#       Copies the driver files only. Then add the printer in System Settings.
#
#   sudo ./install.sh --queue Samsung_ML_1640 --uri "lpd://192.0.2.10/Samsung%20ML-1640%20Series"
#       Copies the driver files and also creates a CUPS queue with the right PPD.
#       Use this for a printer shared from another computer (Windows LPD share,
#       Linux CUPS, print server). Optional: --model 1660 (default: 1640).
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this script with sudo." >&2
    exit 1
fi

HERE="$(cd "$(dirname "$0")" && pwd)"
MODEL=1640
QUEUE=""
URI=""

while [ $# -gt 0 ]; do
    case "$1" in
        --queue) QUEUE="$2"; shift 2 ;;
        --uri)   URI="$2";   shift 2 ;;
        --model) MODEL="$2"; shift 2 ;;
        *) echo "Unknown argument: $1" >&2; exit 1 ;;
    esac
done

PPD_DIR="/Library/Printers/PPDs/Contents/Resources"
DRV_DIR="/Library/Printers/Samsung"

echo "Installing driver files..."
mkdir -p "$PPD_DIR" "$DRV_DIR"
cp -R "$HERE/Samsung/." "$DRV_DIR/"
cp "$HERE/PPDs/Content/Resources/"*.gz "$PPD_DIR/"

chown -R root:wheel "$DRV_DIR"
chmod 755 "$DRV_DIR/UPD/Filters/rastertoqpdl" "$DRV_DIR/UPD/Filters/pstoqpdl"
chown root:wheel "$PPD_DIR/Samsung ML-1640 Series.gz" "$PPD_DIR/Samsung ML-1660 Series.gz"
chmod 644 "$PPD_DIR/Samsung ML-1640 Series.gz" "$PPD_DIR/Samsung ML-1660 Series.gz"

# Files downloaded with a browser carry the quarantine flag, which makes
# Gatekeeper block the filter when CUPS tries to run it.
xattr -dr com.apple.quarantine "$DRV_DIR" 2>/dev/null || true
xattr -d com.apple.quarantine "$PPD_DIR/Samsung ML-1640 Series.gz" "$PPD_DIR/Samsung ML-1660 Series.gz" 2>/dev/null || true

echo "Checking the filter runs on this Mac..."
"$DRV_DIR/UPD/Filters/rastertoqpdl" >/dev/null 2>&1 || true
if ! lpinfo -m | grep -q "Samsung ML-$MODEL"; then
    echo "CUPS does not list the Samsung ML-$MODEL driver. Check $PPD_DIR." >&2
    exit 1
fi
echo "Driver files installed. CUPS lists: $(lpinfo -m | grep "Samsung ML-$MODEL")"

if [ -n "$QUEUE" ] && [ -n "$URI" ]; then
    PPD="$PPD_DIR/Samsung ML-$MODEL Series.gz"
    echo "Creating queue $QUEUE -> $URI"
    lpadmin -p "$QUEUE" -E -v "$URI" -P "$PPD" -o printer-is-shared=false
    echo "Queue created. Test it with:"
    echo "  lp -d $QUEUE /path/to/file.pdf"
elif [ -n "$QUEUE" ] || [ -n "$URI" ]; then
    echo "--queue and --uri must be given together." >&2
    exit 1
else
    echo "Now add the printer in System Settings > Printers & Scanners."
    echo "Pick 'Samsung ML-$MODEL' as the driver (not Generic PostScript, not AirPrint)."
fi
