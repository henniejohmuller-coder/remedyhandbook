"""
Run this once from your project root: python fix_web_index.py
It removes the Noto Color Emoji font link from web/index.html so the
"Failed to fetch" console error disappears.
"""
import re, pathlib

path = pathlib.Path('web/index.html')
if not path.exists():
    print("web/index.html not found — run 'flutter create .' first to generate it")
    raise SystemExit(1)

html = path.read_text(encoding='utf-8')

# Remove any <link> tags that reference Noto Color Emoji
cleaned = re.sub(
    r'\s*<link[^>]+notocoloremoji[^>]+>\s*',
    '\n',
    html,
    flags=re.IGNORECASE,
)

if cleaned == html:
    print("No Noto Color Emoji link found — nothing to remove.")
else:
    path.write_text(cleaned, encoding='utf-8')
    print("Done — Noto Color Emoji font link removed from web/index.html")
