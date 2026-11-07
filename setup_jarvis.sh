
{\rtf1\ansi\ansicpg1252\cocoartf2870
\cocoatextscaling0\cocoaplatform0{\fonttbl\f0\fswiss\fcharset0 Helvetica;}
{\colortbl;\red255\green255\blue255;}
{\*\expandedcolortbl;;}
\paperw11900\paperh16840\margl1440\margr1440\vieww11520\viewh8400\viewkind0
\pard\tx720\tx1440\tx2160\tx2880\tx3600\tx4320\tx5040\tx5760\tx6480\tx7200\tx7920\tx8640\pardirnatural\partightenfactor0

\f0\fs24 \cf0 #!/usr/bin/env bash\
set -euo pipefail\
\
# ============================================================\
# JARVIS / Mark-LIII Integration & macOS Packaging Setup\
#\
# Run from the root of your JARVIS Git repository:\
#\
#   chmod +x setup_jarvis.sh\
#   ./setup_jarvis.sh\
#\
# This script:\
#   1. Verifies the JARVIS Git repository\
#   2. Clones latest Mark-LIII temporarily\
#   3. Merges Mark-LIII source into JARVIS\
#   4. Adds AI News Intelligence\
#   5. Adds macOS packaging\
#   6. Adds GitHub Actions macOS build\
#   7. Creates/updates .gitignore\
#   8. Scans for obvious secrets\
#   9. Runs Python syntax checks\
#  10. Shows Git changes\
#\
# IMPORTANT:\
#   This script NEVER performs git push automatically.\
# ============================================================\
\
REPO_URL="https://github.com/FatihMakes/Mark-LIII.git"\
TMP_DIR="$(mktemp -d "$\{TMPDIR:-/tmp\}/jarvis-markliii.XXXXXX")"\
\
cleanup() \{\
    rm -rf "$TMP_DIR"\
\}\
trap cleanup EXIT\
\
die() \{\
    echo ""\
    echo "ERROR: $*" >&2\
    exit 1\
\}\
\
info() \{\
    echo ""\
    echo "==> $*"\
\}\
\
# ============================================================\
# 1. Verify Git repository\
# ============================================================\
\
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" \\\
    || die "Run this script from inside your JARVIS Git repository."\
\
cd "$ROOT"\
\
echo "============================================================"\
echo " JARVIS / Mark-LIII Integration"\
echo "============================================================"\
echo ""\
echo "Repository:"\
echo "  $ROOT"\
\
BRANCH="$(git branch --show-current)"\
\
echo "Branch:"\
echo "  $\{BRANCH:-unknown\}"\
\
REMOTE="$(git remote get-url origin 2>/dev/null || true)"\
\
if [[ -n "$REMOTE" ]]; then\
    echo "Remote:"\
    echo "  $REMOTE"\
else\
    echo "WARNING: origin remote is not configured."\
fi\
\
# ============================================================\
# 2. Protect existing changes\
# ============================================================\
\
if [[ -n "$(git status --porcelain)" ]]; then\
\
    echo ""\
    echo "WARNING: Your working tree already contains changes:"\
    echo ""\
\
    git status --short\
\
    echo ""\
    read -r -p \\\
        "Continue and merge Mark-LIII into this working tree? [y/N] " ANSWER\
\
    if [[ ! "$ANSWER" =~ ^[Yy]$ ]]; then\
        die "Aborted."\
    fi\
fi\
\
# ============================================================\
# 3. Clone Mark-LIII temporarily\
# ============================================================\
\
info "Cloning latest Mark-LIII..."\
\
git clone \\\
    --depth 1 \\\
    "$REPO_URL" \\\
    "$TMP_DIR/Mark-LIII"\
\
MARK_ROOT="$TMP_DIR/Mark-LIII"\
\
[[ -f "$MARK_ROOT/main.py" ]] \\\
    || die "Mark-LIII main.py not found."\
\
[[ -d "$MARK_ROOT/actions" ]] \\\
    || die "Mark-LIII actions/ not found."\
\
[[ -d "$MARK_ROOT/plugins" ]] \\\
    || die "Mark-LIII plugins/ not found."\
\
# ============================================================\
# 4. Merge Mark-LIII\
# ============================================================\
\
info "Merging Mark-LIII source..."\
\
rsync -a \\\
    --exclude=".git/" \\\
    --exclude=".github/" \\\
    --exclude="build/" \\\
    --exclude="dist/" \\\
    --exclude="__pycache__/" \\\
    --exclude=".DS_Store" \\\
    --exclude="config/api_keys.json" \\\
    "$MARK_ROOT/" \\\
    "$ROOT/"\
\
echo "Mark-LIII source imported."\
\
# ============================================================\
# 5. AI News Intelligence\
# ============================================================\
\
info "Installing AI News Intelligence..."\
\
mkdir -p "$ROOT/plugins"\
\
cat > "$ROOT/plugins/ai_news.py" <<'PYEOF'\
"""\
JARVIS AI News Intelligence\
\
Features:\
- RSS aggregation\
- Web news search\
- Deduplication\
- Gemini summarization\
- Source citation preservation\
- Background topic monitoring\
"""\
\
from __future__ import annotations\
\
import html\
import re\
\
from datetime import datetime, timezone\
from email.utils import parsedate_to_datetime\
from typing import Any\
\
import feedparser\
\
from memory.config_manager import get_gemini_key\
\
from actions.background_monitor import (\
    add_monitor,\
    remove_monitor,\
    list_monitors,\
)\
\
\
PLUGIN = \{\
    "name": "ai_news",\
\
    "description": (\
        "AI News Intelligence. Retrieves current AI news from RSS and web "\
        "search, summarizes it with Gemini, preserves source URLs, and "\
        "supports background topic monitoring."\
    ),\
\
    "parameters": \{\
        "type": "OBJECT",\
\
        "properties": \{\
\
            "action": \{\
                "type": "STRING",\
                "description": (\
                    "briefing, search, monitor_add, "\
                    "monitor_remove, monitor_list"\
                ),\
            \},\
\
            "topic": \{\
                "type": "STRING",\
                "description": (\
                    "AI topic, company, technology, "\
                    "or industry to search."\
                ),\
            \},\
\
            "limit": \{\
                "type": "INTEGER",\
                "description": (\
                    "Maximum number of articles. "\
                    "Default 8, maximum 15."\
                ),\
            \},\
\
            "hours": \{\
                "type": "INTEGER",\
                "description": (\
                    "Recent-news window in hours. "\
                    "Default 48, maximum 168."\
                ),\
            \},\
        \},\
\
        "required": [],\
    \},\
\}\
\
\
RSS_FEEDS = [\
\
    (\
        "Google AI Blog",\
        "https://blog.google/technology/ai/rss/",\
    ),\
\
    (\
        "Hugging Face Blog",\
        "https://huggingface.co/blog/feed.xml",\
    ),\
\
    (\
        "MIT Technology Review - AI",\
        "https://www.technologyreview.com/topic/artificial-intelligence/feed/",\
    ),\
\
    (\
        "TechCrunch - AI",\
        "https://techcrunch.com/category/artificial-intelligence/feed/",\
    ),\
\
    (\
        "VentureBeat - AI",\
        "https://venturebeat.com/category/ai/feed/",\
    ),\
\
    (\
        "The Verge - AI",\
        "https://www.theverge.com/rss/ai-artificial-intelligence/index.xml",\
    ),\
\
    (\
        "Ars Technica",\
        "https://feeds.arstechnica.com/arstechnica/technology-lab",\
    ),\
]\
\
\
DEFAULT_LIMIT = 8\
MAX_LIMIT = 15\
DEFAULT_HOURS = 48\
\
\
def _clean_html(value: str) -> str:\
\
    if not value:\
        return ""\
\
    value = html.unescape(value)\
\
    value = re.sub(\
        r"<script\\b[^>]*>.*?</script>",\
        " ",\
        value,\
        flags=re.I | re.S,\
    )\
\
    value = re.sub(\
        r"<style\\b[^>]*>.*?</style>",\
        " ",\
        value,\
        flags=re.I | re.S,\
    )\
\
    value = re.sub(\
        r"<[^>]+>",\
        " ",\
        value,\
    )\
\
    return re.sub(\
        r"\\s+",\
        " ",\
        value,\
    ).strip()\
\
\
def _parse_date(entry: Any):\
\
    raw = (\
        entry.get("published")\
        or entry.get("updated")\
        or entry.get("created")\
    )\
\
    if not raw:\
        return None\
\
    try:\
\
        dt = parsedate_to_datetime(raw)\
\
        if dt.tzinfo is None:\
            dt = dt.replace(tzinfo=timezone.utc)\
\
        return dt.astimezone(timezone.utc)\
\
    except Exception:\
\
        return None\
\
\
def _fetch_rss(\
    topic: str,\
    limit: int,\
    hours: int,\
):\
\
    cutoff = (\
        datetime.now(timezone.utc).timestamp()\
        - max(1, hours) * 3600\
    )\
\
    terms = [\
        x.lower()\
        for x in re.findall(r"\\w+", topic or "")\
        if len(x) > 2\
    ]\
\
    rows = []\
    seen = set()\
\
    for source, feed_url in RSS_FEEDS:\
\
        try:\
\
            feed = feedparser.parse(feed_url)\
\
            for entry in feed.entries[:25]:\
\
                title = _clean_html(\
                    entry.get("title", "")\
                )\
\
                url = entry.get("link", "")\
\
                if not title or not url or url in seen:\
                    continue\
\
                summary = _clean_html(\
                    entry.get("summary")\
                    or entry.get("description")\
                    or ""\
                )[:1400]\
\
                dt = _parse_date(entry)\
\
                if (\
                    dt\
                    and dt.timestamp() < cutoff\
                ):\
                    continue\
\
                if terms:\
\
                    haystack = (\
                        f"\{title\} \{summary\}"\
                    ).lower()\
\
                    if not any(\
                        term in haystack\
                        for term in terms\
                    ):\
                        continue\
\
                seen.add(url)\
\
                rows.append(\
                    \{\
                        "title": title,\
                        "source": source,\
                        "url": url,\
                        "published": (\
                            dt.isoformat()\
                            if dt\
                            else ""\
                        ),\
                        "summary": summary,\
                        "method": "RSS",\
                    \}\
                )\
\
        except Exception as exc:\
\
            print(\
                f"[AI News] RSS failed: "\
                f"\{source\}: \{exc\}"\
            )\
\
    rows.sort(\
        key=lambda x: x.get(\
            "published",\
            "",\
        ),\
        reverse=True,\
    )\
\
    return rows[:limit]\
\
\
def _web_news(\
    topic: str,\
    limit: int,\
):\
\
    try:\
\
        from actions.web_search import _ddg_news\
\
        results = _ddg_news(\
            topic or "artificial intelligence",\
            max_results=limit,\
        )\
\
        output = []\
\
        for item in results or []:\
\
            output.append(\
                \{\
                    "title": _clean_html(\
                        item.get("title", "")\
                    ),\
\
                    "source": (\
                        item.get("source", "")\
                        or "Web News"\
                    ),\
\
                    "url": item.get(\
                        "url",\
                        "",\
                    ),\
\
                    "published": item.get(\
                        "date",\
                        "",\
                    ),\
\
                    "summary": _clean_html(\
                        item.get(\
                            "snippet",\
                            "",\
                        )\
                    )[:1400],\
\
                    "method": "Web Search",\
                \}\
            )\
\
        return [\
            x\
            for x in output\
            if x["title"] and x["url"]\
        ]\
\
    except Exception as exc:\
\
        print(\
            f"[AI News] Web search failed: \{exc\}"\
        )\
\
        return []\
\
\
def _dedupe(\
    items,\
    limit,\
):\
\
    output = []\
    seen = set()\
\
    for item in items:\
\
        key = re.sub(\
            r"[^a-z0-9]+",\
            " ",\
            item.get(\
                "title",\
                "",\
            ).lower(),\
        ).strip()\
\
        key = (\
            key\
            or item.get(\
                "url",\
                "",\
            )\
        )\
\
        if key in seen:\
            continue\
\
        seen.add(key)\
\
        output.append(item)\
\
        if len(output) >= limit:\
            break\
\
    return output\
\
\
def _summarize(\
    items,\
    topic,\
):\
\
    api_key = get_gemini_key()\
\
    if not api_key:\
\
        return (\
            "Gemini summary is unavailable because "\
            "the Mark-LIII Gemini API key is not configured."\
        )\
\
    try:\
\
        from google import genai\
\
        client = genai.Client(\
            api_key=api_key\
        )\
\
        articles = []\
\
        for i, item in enumerate(\
            items,\
            1,\
        ):\
\
            articles.append(\
                f"""\
ARTICLE \{i\}\
\
Title:\
\{item.get("title", "")\}\
\
Source:\
\{item.get("source", "")\}\
\
Published:\
\{item.get("published", "")\}\
\
URL:\
\{item.get("url", "")\}\
\
Summary:\
\{item.get("summary", "")[:4500]\}\
"""\
            )\
\
        prompt = f"""\
You are JARVIS's AI News Intelligence analyst.\
\
Topic:\
\{topic or "Artificial Intelligence"\}\
\
Analyze only the supplied articles.\
\
Rules:\
\
- Do not invent facts.\
- Do not invent sources.\
- Do not invent dates.\
- Do not invent quotes.\
- Do not invent URLs.\
- Preserve source attribution.\
- Prioritize material developments.\
- Separate facts from implications.\
\
When relevant, assess implications for:\
\
- enterprise AI\
- telecom\
- cloud\
- AI infrastructure\
- AI sovereignty\
- Indonesia\
- Telkom\
\
Return:\
\
1. Executive briefing\
2. Top 3-5 developments\
3. For each:\
   WHAT HAPPENED\
   WHY IT MATTERS\
   IMPACT\
4. WATCH NEXT\
\
Preserve supplied source URLs exactly.\
\
ARTICLES:\
\
\{chr(10).join(articles)\}\
"""\
\
        response = client.models.generate_content(\
            model="gemini-2.5-flash",\
            contents=prompt,\
        )\
\
        return (\
            response.text or ""\
        ).strip()\
\
    except Exception as exc:\
\
        print(\
            f"[AI News] Gemini failed: \{exc\}"\
        )\
\
        return (\
            "News collection succeeded, "\
            f"but Gemini summarization failed: \{exc\}"\
        )\
\
\
def _sources(items):\
\
    lines = [\
        "SOURCES"\
    ]\
\
    for i, item in enumerate(\
        items,\
        1,\
    ):\
\
        lines.append(\
            f"\{i\}. "\
            f"\{item.get('title', 'Untitled')\} \'97 "\
            f"\{item.get('source', 'Unknown')\} \'97 "\
            f"\{item.get('published') or 'date unavailable'\}\\n"\
            f"   \{item.get('url', '')\}"\
        )\
\
    return "\\n".join(lines)\
\
\
def _briefing(\
    topic,\
    limit,\
    hours,\
):\
\
    rss = _fetch_rss(\
        topic,\
        limit,\
        hours,\
    )\
\
    web = _web_news(\
        topic or "artificial intelligence",\
        max(4, limit // 2),\
    )\
\
    items = _dedupe(\
        rss + web,\
        limit,\
    )\
\
    if not items:\
\
        return (\
            "I could not find current AI news "\
            "from the configured sources."\
        )\
\
    return (\
        _summarize(\
            items,\
            topic,\
        )\
        + "\\n\\n"\
        + _sources(items)\
    )\
\
\
def run(\
    parameters: dict,\
    player=None,\
    session_memory=None,\
):\
\
    action = str(\
        parameters.get(\
            "action",\
            "briefing",\
        )\
        or "briefing"\
    ).lower().strip()\
\
    topic = str(\
        parameters.get(\
            "topic",\
            "",\
        )\
        or ""\
    ).strip()\
\
    try:\
\
        limit = max(\
            1,\
            min(\
                int(\
                    parameters.get(\
                        "limit",\
                        DEFAULT_LIMIT,\
                    )\
                ),\
                MAX_LIMIT,\
            ),\
        )\
\
    except Exception:\
\
        limit = DEFAULT_LIMIT\
\
    try:\
\
        hours = max(\
            1,\
            min(\
                int(\
                    parameters.get(\
                        "hours",\
                        DEFAULT_HOURS,\
                    )\
                ),\
                168,\
            ),\
        )\
\
    except Exception:\
\
        hours = DEFAULT_HOURS\
\
    try:\
\
        if action == "monitor_add":\
\
            if not topic:\
                return (\
                    "Please specify the AI topic "\
                    "to monitor."\
                )\
\
            return add_monitor(topic)\
\
        if action == "monitor_remove":\
\
            if not topic:\
                return (\
                    "Please specify the monitored "\
                    "topic to remove."\
                )\
\
            return remove_monitor(topic)\
\
        if action == "monitor_list":\
\
            topics = list_monitors()\
\
            if not topics:\
\
                return (\
                    "No background news topics "\
                    "are currently being monitored."\
                )\
\
            return (\
                "Currently monitored topics: "\
                + "; ".join(topics)\
            )\
\
        return _briefing(\
            topic,\
            limit,\
            hours,\
        )\
\
    except Exception as exc:\
\
        print(\
            f"[AI News] Plugin error: \{exc\}"\
        )\
\
        return (\
            f"Sir, the AI News plugin failed: \{exc\}"\
        )\
PYEOF\
\
# ============================================================\
# 6. requirements.txt\
# ============================================================\
\
info "Updating requirements.txt..."\
\
touch "$ROOT/requirements.txt"\
\
if ! grep -qE '^feedparser([<>=]|$)' \\\
    "$ROOT/requirements.txt"; then\
\
    echo "feedparser>=6.0.11" \\\
        >> "$ROOT/requirements.txt"\
\
fi\
\
# ============================================================\
# 7. AI News prompt\
# ============================================================\
\
info "Updating core/prompt.txt..."\
\
PROMPT="$ROOT/core/prompt.txt"\
\
[[ -f "$PROMPT" ]] \\\
    || die "core/prompt.txt not found."\
\
if ! grep -q \\\
    "AI NEWS INTELLIGENCE" \\\
    "$PROMPT"; then\
\
cat >> "$PROMPT" <<'PROMPTEOF'\
\
\
AI NEWS INTELLIGENCE:\
\
- ai_news is the preferred tool for CURRENT AI news,\
  today's AI briefing, latest AI developments,\
  AI agents, foundation models, AI infrastructure,\
  AI regulation, or AI news relevant to a company\
  or industry.\
\
- For current news, prefer ai_news instead of answering\
  from memory.\
\
- ai_news combines RSS feeds and web-news search,\
  then uses Gemini to analyze the articles.\
\
- Always preserve and mention original source URLs.\
\
- Never invent a source, date, headline, quote,\
  or URL.\
\
- If the user asks to monitor an AI topic, use:\
  action = monitor_add.\
\
- If the user asks what topics are being monitored,\
  use:\
  action = monitor_list.\
\
- If the user asks to stop monitoring a topic,\
  use:\
  action = monitor_remove.\
\
- When analyzing AI news for Telkom, explicitly assess\
  business, technology, telecom, cloud, infrastructure,\
  AI sovereignty, and strategic implications.\
\
- Use web_search research mode for deep historical\
  or technical investigations.\
PROMPTEOF\
\
fi\
\
# ============================================================\
# 8. macOS packaging\
# ============================================================\
\
info "Creating macOS packaging..."\
\
mkdir -p \\\
    "$ROOT/macos" \\\
    "$ROOT/.github/workflows"\
\
# ------------------------------------------------------------\
# JARVIS.spec\
# ------------------------------------------------------------\
\
cat > "$ROOT/macos/JARVIS.spec" <<'SPECEOF'\
from pathlib import Path\
\
from PyInstaller.utils.hooks import (\
    collect_submodules,\
)\
\
ROOT = Path(__file__).resolve().parent.parent\
\
\
hiddenimports = []\
\
for package in [\
    "google",\
    "google.genai",\
    "playwright",\
    "feedparser",\
]:\
\
    try:\
\
        hiddenimports += collect_submodules(\
            package\
        )\
\
    except Exception:\
        pass\
\
\
datas = []\
\
for folder in [\
    "core",\
    "actions",\
    "plugins",\
    "dashboard",\
]:\
\
    path = ROOT / folder\
\
    if path.exists():\
\
        datas.append(\
            (\
                str(path),\
                folder,\
            )\
        )\
\
\
a = Analysis(\
    [str(ROOT / "main.py")],\
    pathex=[str(ROOT)],\
    binaries=[],\
    datas=datas,\
    hiddenimports=hiddenimports,\
    hookspath=[],\
    hooksconfig=\{\},\
    runtime_hooks=[],\
    excludes=[],\
    noarchive=False,\
)\
\
\
pyz = PYZ(a.pure)\
\
\
exe = EXE(\
    pyz,\
    a.scripts,\
    [],\
    exclude_binaries=True,\
    name="JARVIS",\
    debug=False,\
    bootloader_ignore_signals=False,\
    strip=False,\
    upx=False,\
    console=False,\
)\
\
\
app = BUNDLE(\
    exe,\
    a.binaries,\
    a.datas,\
    name="JARVIS.app",\
    bundle_identifier="id.telkom.jarvis",\
    info_plist=\{\
        "CFBundleName": "JARVIS",\
        "CFBundleDisplayName": "JARVIS",\
        "CFBundleIdentifier": "id.telkom.jarvis",\
        "CFBundleShortVersionString": "1.0.0",\
        "CFBundleVersion": "1",\
\
        "NSMicrophoneUsageDescription":\
            "JARVIS requires microphone access for voice interaction.",\
\
        "NSCameraUsageDescription":\
            "JARVIS requires camera access for visual awareness.",\
\
        "NSAppleEventsUsageDescription":\
            "JARVIS requires Apple Events access to control supported applications.",\
    \},\
)\
SPECEOF\
\
# ------------------------------------------------------------\
# build_mac.sh\
# ------------------------------------------------------------\
\
cat > "$ROOT/macos/build_mac.sh" <<'BUILDEOF'\
#!/usr/bin/env bash\
\
set -euo pipefail\
\
ROOT="$(cd "$(dirname "$\{BASH_SOURCE[0]\}")/.." && pwd)"\
\
cd "$ROOT"\
\
echo "==> Installing dependencies"\
\
python3 -m pip install \\\
    --upgrade pip\
\
python3 -m pip install \\\
    -r requirements.txt\
\
python3 -m pip install \\\
    --upgrade pyinstaller\
\
echo "==> Installing Playwright Chromium"\
\
python3 -m playwright install chromium\
\
echo "==> Cleaning previous build"\
\
rm -rf build dist\
\
echo "==> Building JARVIS.app"\
\
python3 -m PyInstaller \\\
    --noconfirm \\\
    --clean \\\
    macos/JARVIS.spec\
\
if [[ ! -d "dist/JARVIS.app" ]]; then\
\
    echo "ERROR: JARVIS.app was not generated."\
\
    exit 1\
\
fi\
\
echo ""\
echo "============================================================"\
echo " BUILD SUCCESSFUL"\
echo "============================================================"\
echo ""\
echo "Application:"\
echo ""\
echo "  $ROOT/dist/JARVIS.app"\
echo ""\
echo "Test:"\
echo ""\
echo "  open \\"$ROOT/dist/JARVIS.app\\""\
echo ""\
BUILDEOF\
\
# ------------------------------------------------------------\
# macOS Keychain\
# ------------------------------------------------------------\
\
cat > "$ROOT/macos/macos_keychain.py" <<'KEYEOF'\
"""\
macOS Keychain helper for JARVIS.\
"""\
\
from __future__ import annotations\
\
import subprocess\
\
\
SERVICE = "id.telkom.jarvis"\
ACCOUNT = "gemini_api_key"\
\
\
def get_secret():\
\
    try:\
\
        result = subprocess.run(\
            [\
                "security",\
                "find-generic-password",\
                "-a",\
                ACCOUNT,\
                "-s",\
                SERVICE,\
                "-w",\
            ],\
            capture_output=True,\
            text=True,\
            check=False,\
        )\
\
        value = result.stdout.strip()\
\
        return value or None\
\
    except Exception:\
\
        return None\
\
\
def set_secret(value):\
\
    try:\
\
        result = subprocess.run(\
            [\
                "security",\
                "add-generic-password",\
                "-a",\
                ACCOUNT,\
                "-s",\
                SERVICE,\
                "-w",\
                value,\
                "-U",\
            ],\
            capture_output=True,\
            text=True,\
            check=False,\
        )\
\
        return result.returncode == 0\
\
    except Exception:\
\
        return False\
\
\
def delete_secret():\
\
    try:\
\
        result = subprocess.run(\
            [\
                "security",\
                "delete-generic-password",\
                "-a",\
                ACCOUNT,\
                "-s",\
                SERVICE,\
            ],\
            capture_output=True,\
            text=True,\
            check=False,\
        )\
\
        return result.returncode == 0\
\
    except Exception:\
\
        return False\
KEYEOF\
\
# ------------------------------------------------------------\
# macOS tray\
# ------------------------------------------------------------\
\
cat > "$ROOT/macos/macos_tray.py" <<'TRAYEOF'\
"""\
JARVIS macOS menu-bar integration.\
"""\
\
from __future__ import annotations\
\
\
try:\
\
    from PyQt6.QtGui import QAction\
\
    from PyQt6.QtWidgets import (\
        QMenu,\
        QSystemTrayIcon,\
    )\
\
except Exception:\
\
    QAction = None\
    QMenu = None\
    QSystemTrayIcon = None\
\
\
def install_tray(\
    app,\
    window,\
):\
\
    if QSystemTrayIcon is None:\
        return None\
\
    if not QSystemTrayIcon.isSystemTrayAvailable():\
        return None\
\
    tray = QSystemTrayIcon(\
        window.windowIcon(),\
        parent=window,\
    )\
\
    menu = QMenu()\
\
    show_action = QAction(\
        "Show JARVIS",\
        menu,\
    )\
\
    show_action.triggered.connect(\
        window.show\
    )\
\
    menu.addAction(\
        show_action\
    )\
\
    hide_action = QAction(\
        "Hide JARVIS",\
        menu,\
    )\
\
    hide_action.triggered.connect(\
        window.hide\
    )\
\
    menu.addAction(\
        hide_action\
    )\
\
    menu.addSeparator()\
\
    quit_action = QAction(\
        "Quit JARVIS",\
        menu,\
    )\
\
    quit_action.triggered.connect(\
        app.quit\
    )\
\
    menu.addAction(\
        quit_action\
    )\
\
    tray.setContextMenu(\
        menu\
    )\
\
    tray.setToolTip(\
        "JARVIS"\
    )\
\
    tray.show()\
\
    return tray\
TRAYEOF\
\
# ------------------------------------------------------------\
# macOS application support\
# ------------------------------------------------------------\
\
cat > "$ROOT/macos/macos_app.py" <<'APPEOF'\
"""\
macOS application support utilities.\
"""\
\
from __future__ import annotations\
\
from pathlib import Path\
\
\
APP_SUPPORT = (\
    Path.home()\
    / "Library"\
    / "Application Support"\
    / "JARVIS"\
)\
\
\
def ensure_app_support():\
\
    APP_SUPPORT.mkdir(\
        parents=True,\
        exist_ok=True,\
    )\
\
    return APP_SUPPORT\
\
\
def is_macos():\
\
    return (\
        __import__(\
            "platform"\
        ).system()\
        == "Darwin"\
    )\
APPEOF\
\
# ------------------------------------------------------------\
# install_mac.sh\
# ------------------------------------------------------------\
\
cat > "$ROOT/macos/install_mac.sh" <<'INSTALLEOF'\
#!/usr/bin/env bash\
\
set -euo pipefail\
\
ROOT="$(cd "$(dirname "$\{BASH_SOURCE[0]\}")/.." && pwd)"\
\
APP="$ROOT/dist/JARVIS.app"\
\
TARGET="/Applications/JARVIS.app"\
\
PLIST="$HOME/Library/LaunchAgents/id.telkom.jarvis.plist"\
\
\
if [[ ! -d "$APP" ]]; then\
\
    echo "ERROR:"\
    echo "JARVIS.app not found."\
\
    echo ""\
    echo "Run first:"\
    echo ""\
    echo "  ./macos/build_mac.sh"\
\
    exit 1\
\
fi\
\
\
echo "==> Installing JARVIS.app"\
\
rm -rf "$TARGET"\
\
ditto \\\
    "$APP" \\\
    "$TARGET"\
\
\
echo "==> Creating LaunchAgent"\
\
mkdir -p \\\
    "$HOME/Library/LaunchAgents"\
\
\
cat > "$PLIST" <<'PLISTEOF'\
<?xml version="1.0" encoding="UTF-8"?>\
\
<!DOCTYPE plist PUBLIC\
"-//Apple//DTD PLIST 1.0//EN"\
"http://www.apple.com/DTDs/PropertyList-1.0.dtd">\
\
<plist version="1.0">\
\
<dict>\
\
    <key>Label</key>\
    <string>id.telkom.jarvis</string>\
\
    <key>ProgramArguments</key>\
\
    <array>\
\
        <string>\
        /Applications/JARVIS.app/Contents/MacOS/JARVIS\
        </string>\
\
    </array>\
\
    <key>RunAtLoad</key>\
    <true/>\
\
    <key>KeepAlive</key>\
    <false/>\
\
</dict>\
\
</plist>\
PLISTEOF\
\
\
launchctl bootout \\\
    "gui/$(id -u)" \\\
    "$PLIST" \\\
    2>/dev/null || true\
\
\
launchctl bootstrap \\\
    "gui/$(id -u)" \\\
    "$PLIST"\
\
\
echo ""\
echo "============================================================"\
echo " JARVIS INSTALLED"\
echo "============================================================"\
echo ""\
echo "Application:"\
echo ""\
echo "  /Applications/JARVIS.app"\
echo ""\
echo "LaunchAgent:"\
echo ""\
echo "  $PLIST"\
echo ""\
echo "Start:"\
echo ""\
echo "  open /Applications/JARVIS.app"\
echo ""\
INSTALLEOF\
\
# ------------------------------------------------------------\
# uninstall_mac.sh\
# ------------------------------------------------------------\
\
cat > "$ROOT/macos/uninstall_mac.sh" <<'UNINSTALLEOF'\
#!/usr/bin/env bash\
\
set -euo pipefail\
\
TARGET="/Applications/JARVIS.app"\
\
PLIST="$HOME/Library/LaunchAgents/id.telkom.jarvis.plist"\
\
\
echo "==> Removing LaunchAgent"\
\
if [[ -f "$PLIST" ]]; then\
\
    launchctl bootout \\\
        "gui/$(id -u)" \\\
        "$PLIST" \\\
        2>/dev/null || true\
\
    rm -f "$PLIST"\
\
fi\
\
\
echo "==> Removing JARVIS.app"\
\
rm -rf "$TARGET"\
\
\
echo ""\
echo "JARVIS.app removed."\
\
echo ""\
echo "User data was NOT removed:"\
echo ""\
echo "  ~/Library/Application Support/JARVIS"\
echo ""\
echo "Gemini Keychain credential was NOT removed."\
echo ""\
UNINSTALLEOF\
\
\
chmod +x \\\
    "$ROOT/macos/"*.sh\
\
# ============================================================\
# 9. GitHub Actions\
# ============================================================\
\
info "Creating GitHub Actions macOS workflow..."\
\
cat > "$ROOT/.github/workflows/build-macos.yml" <<'YAMLEOF'\
name: Build JARVIS macOS\
\
on:\
\
  workflow_dispatch:\
\
  push:\
    branches:\
      - main\
\
\
jobs:\
\
  build:\
\
    runs-on: macos-latest\
\
    steps:\
\
      - name: Checkout\
        uses: actions/checkout@v4\
\
\
      - name: Setup Python\
        uses: actions/setup-python@v5\
\
        with:\
          python-version: "3.11"\
\
\
      - name: Build JARVIS\
        run: |\
\
          chmod +x macos/build_mac.sh\
\
          ./macos/build_mac.sh\
\
\
      - name: Package JARVIS\
        run: |\
\
          ditto \\\
            -c \\\
            -k \\\
            --sequesterRsrc \\\
            --keepParent \\\
            "dist/JARVIS.app" \\\
            "JARVIS-macOS.zip"\
\
\
      - name: Upload Artifact\
        uses: actions/upload-artifact@v4\
\
        with:\
\
          name: JARVIS-macOS\
\
          path: JARVIS-macOS.zip\
YAMLEOF\
\
# ============================================================\
# 10. .gitignore\
# ============================================================\
\
info "Updating .gitignore..."\
\
touch "$ROOT/.gitignore"\
\
\
add_ignore() \{\
\
    LINE="$1"\
\
    if ! grep -qxF "$LINE" "$ROOT/.gitignore" 2>/dev/null; then\
\
        echo "$LINE" >> "$ROOT/.gitignore"\
\
    fi\
\}\
\
\
add_ignore "__pycache__/"\
add_ignore "*.py[cod]"\
add_ignore ".venv/"\
add_ignore "venv/"\
add_ignore ".env"\
add_ignore ".env.*"\
add_ignore "config/api_keys.json"\
add_ignore ".DS_Store"\
add_ignore "build/"\
add_ignore "dist/"\
add_ignore "*.log"\
add_ignore ".vscode/"\
add_ignore ".idea/"\
\
# IMPORTANT:\
# Do NOT ignore the whole memory directory because\
# source code may legitimately use it.\
# Only local runtime JSON is ignored.\
\
add_ignore "memory/*.json"\
\
# ============================================================\
# 11. Security scan\
# ============================================================\
\
info "Scanning for potential secrets..."\
\
SECRET_PATTERN='AIza[0-9A-Za-z_-]\{20,\}|sk-[A-Za-z0-9_-]\{20,\}|BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY'\
\
if grep -RInE \\\
    --exclude-dir=.git \\\
    --exclude-dir=dist \\\
    --exclude-dir=build \\\
    --exclude='*.png' \\\
    --exclude='*.jpg' \\\
    --exclude='*.jpeg' \\\
    --exclude='*.icns' \\\
    --exclude='*.zip' \\\
    "$SECRET_PATTERN" \\\
    "$ROOT" \\\
    >/tmp/jarvis_secret_scan.txt \\\
    2>/dev/null\
then\
\
    echo ""\
    echo "Potential secret detected:"\
    echo ""\
\
    cat /tmp/jarvis_secret_scan.txt\
\
    echo ""\
\
    die \\\
        "Remove/rotate the secret before committing."\
\
else\
\
    echo "Secret scan: OK"\
\
fi\
\
# ============================================================\
# 12. Required file check\
# ============================================================\
\
info "Checking required files..."\
\
REQUIRED_FILES=(\
\
    "main.py"\
    "requirements.txt"\
\
    "core/prompt.txt"\
\
    "plugins/ai_news.py"\
\
    "macos/JARVIS.spec"\
    "macos/build_mac.sh"\
    "macos/install_mac.sh"\
    "macos/uninstall_mac.sh"\
\
    ".github/workflows/build-macos.yml"\
\
)\
\
\
for FILE in "$\{REQUIRED_FILES[@]\}"; do\
\
    if [[ ! -f "$ROOT/$FILE" ]]; then\
\
        die \\\
            "Required file missing: $FILE"\
\
    fi\
\
done\
\
\
echo "Required file check: OK"\
\
# ============================================================\
# 13. Python syntax check\
# ============================================================\
\
info "Running Python syntax checks..."\
\
python3 -m compileall -q \\\
    "$ROOT/main.py" \\\
    "$ROOT/actions" \\\
    "$ROOT/core" \\\
    "$ROOT/plugins" \\\
    "$ROOT/memory" \\\
    "$ROOT/macos"\
\
\
echo "Python syntax: OK"\
\
# ============================================================\
# 14. Git status\
# ============================================================\
\
info "Git status"\
\
echo ""\
\
git status --short\
\
echo ""\
\
echo "============================================================"\
echo " JARVIS SETUP COMPLETE"\
echo "============================================================"\
\
echo ""\
echo "NO git push has been performed."\
echo ""\
\
echo "Review changes:"\
echo ""\
\
echo "  git diff --stat"\
\
echo ""\
\
echo "  git diff"\
\
echo ""\
\
echo "Then:"\
echo ""\
\
echo "  git add ."\
\
echo ""\
\
echo "  git status"\
\
echo ""\
\
echo "  git commit -m \\"Integrate Mark-LIII AI agent and macOS packaging\\""\
\
echo ""\
\
echo "  git push origin $\{BRANCH:-main\}"\
\
echo ""\
\
echo "To build JARVIS.app locally:"\
echo ""\
\
echo "  ./macos/build_mac.sh"\
\
echo ""\
\
echo "Result:"\
echo ""\
\
echo "  dist/JARVIS.app"\
\
echo ""\
\
echo "To install:"\
echo ""\
\
echo "  ./macos/install_mac.sh"\
\
echo ""}
