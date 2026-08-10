#!/usr/bin/env bash
# clean-libs.sh — remove unreferenced library junk from rendered output.
#
# reactable's inline theming registers a per-widget dependency whose name
# contains spaces ("reactable <hash>"). Quarto copies the whole reactable
# package into site_libs under that name on every render, but no page ever
# loads files from it (the theme CSS is inlined in the page head). These
# directories are dead weight and can be deleted after rendering.
#
# Run after `quarto render`:
#   bash scripts/clean-libs.sh
set -u

for libs in docs/site_libs _freeze/site_libs; do
  [ -d "$libs" ] || continue
  find "$libs" -maxdepth 1 -type d -name '* *' -print -exec rm -rf {} +
done
