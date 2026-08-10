#!/usr/bin/env bash
# optimize-media.sh <dir> — shrink PDFs and images in place.
#
#   PDFs  > 1 MB   -> ghostscript /ebook (150 dpi), kept only if smaller
#   PNGs  > 400 KB -> resize to max 1200 px, then pngquant (skipped if larger)
#   JPEGs > 400 KB -> resize to max 1200 px, quality 82
#
# Files are replaced in place; use git to review/restore. Originals remain in
# git history. Requires: ghostscript (gs), ImageMagick (magick), pngquant.
set -u
dir="${1:?usage: optimize-media.sh <directory>}"

shrink_pdf() {
  f="$1"; tmp="${f%.pdf}.opt.pdf"
  gs -sDEVICE=pdfwrite -dPDFSETTINGS=/ebook -dNOPAUSE -dQUIET -dBATCH \
     -sOutputFile="$tmp" "$f" 2>/dev/null || { rm -f "$tmp"; return; }
  if [ -f "$tmp" ] && [ "$(stat -f%z "$tmp")" -lt "$(stat -f%z "$f")" ]; then
    mv "$tmp" "$f"; echo "pdf  $f"
  else
    rm -f "$tmp"
  fi
}

shrink_img() {
  f="$1"
  before=$(stat -f%z "$f")
  magick mogrify -resize '1200x1200>' -strip "$f" 2>/dev/null
  case "$f" in
    *.png)  pngquant --force --skip-if-larger --quality=65-90 --ext .png "$f" 2>/dev/null ;;
    *.jpg|*.jpeg) magick mogrify -quality 82 "$f" 2>/dev/null ;;
  esac
  after=$(stat -f%z "$f")
  [ "$after" -lt "$before" ] && echo "img  $f"
}

find "$dir" -type f -name '*.pdf' -size +1M | while read -r f; do shrink_pdf "$f"; done
find "$dir" -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \) -size +400k \
  | while read -r f; do shrink_img "$f"; done
