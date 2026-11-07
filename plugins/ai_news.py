"""
JARVIS AI News Intelligence plugin for Mark-LIII.

Features:
- RSS aggregation from configurable AI/news feeds.
- Web-news fallback/search using DDGS (already used by Mark-LIII).
- Gemini summarisation and relevance analysis.
- Source/title/date/URL citation preservation.
- Topic monitoring backed by Mark-LIII's existing background_monitor memory.
- No secrets hard-coded; uses Mark-LIII's existing Gemini key config.

Drop this file into plugins/ as ai_news.py.
"""

from __future__ import annotations

import html
import re
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
from typing import Any

import feedparser

from memory.config_manager import get_gemini_key
from actions.background_monitor import (
    add_monitor,
    remove_monitor,
    list_monitors,
)

# ---------------------------------------------------------------------------
# Plugin metadata
# ---------------------------------------------------------------------------

PLUGIN = {
    "name": "ai_news",
    "description": (
        "AI News Intelligence. Use this tool when the user asks for current "
        "AI news, today's AI briefing, latest developments in AI, AI agents, "
        "foundation models, AI infrastructure, AI regulation, or AI news "
        "relevant to a company or industry. It can aggregate RSS feeds, "
        "search current web news, summarize with Gemini, preserve source URLs, "
        "and manage daily topic monitoring. Do not use this for generic "
        "non-current research when web_search research mode is more suitable."
    ),
    "parameters": {
        "type": "OBJECT",
        "properties": {
            "action": {
                "type": "STRING",
                "description": (
                    "One of: briefing, search, monitor_add, monitor_remove, "
                    "monitor_list. Default is briefing."
                ),
            },
            "topic": {
                "type": "STRING",
                "description": (
                    "AI topic to search or monitor, e.g. AI agents, sovereign "
                    "AI, Gemini, OpenAI, NVIDIA, AI regulation, Indonesia AI."
                ),
            },
            "limit": {
                "type": "INTEGER",
                "description": "Maximum number of news items. Default 8, max 15.",
            },
            "hours": {
                "type": "INTEGER",
                "description": (
                    "For briefing/search, prefer articles from roughly this "
                    "many recent hours when publication dates are available. "
                    "Default 48."
                ),
            },
        },
        "required": [],
    },
}

# ---------------------------------------------------------------------------
# Feed configuration
# ---------------------------------------------------------------------------

# These are intentionally public RSS/Atom feeds. If a publisher changes its
# feed URL, the plugin skips that source rather than failing the whole briefing.
RSS_FEEDS = [
    ("Google AI Blog", "https://blog.google/technology/ai/rss/"),
    ("Hugging Face Blog", "https://huggingface.co/blog/feed.xml"),
    ("MIT Technology Review - AI", "https://www.technologyreview.com/topic/artificial-intelligence/feed/"),
    ("TechCrunch - AI", "https://techcrunch.com/category/artificial-intelligence/feed/"),
    ("VentureBeat - AI", "https://venturebeat.com/category/ai/feed/"),
    ("The Verge - AI", "https://www.theverge.com/rss/ai-artificial-intelligence/index.xml"),
    ("Ars Technica - AI", "https://feeds.arstechnica.com/arstechnica/technology-lab"),
]

DEFAULT_LIMIT = 8
MAX_LIMIT = 15
DEFAULT_HOURS = 48

# Keep prompts bounded so a large RSS feed cannot consume excessive context.
MAX_SUMMARY_CHARS = 1400
MAX_ARTICLE_CHARS = 4500


def _clean_html(value: str) -> str:
    if not value:
        return ""
    value = html.unescape(value)
    value = re.sub(r"<script\b[^>]*>.*?</script>", " ", value, flags=re.I | re.S)
    value = re.sub(r"<style\b[^>]*>.*?</style>", " ", value, flags=re.I | re.S)
    value = re.sub(r"<[^>]+>", " ", value)
    return re.sub(r"\s+", " ", value).strip()


def _parse_date(entry: Any) -> datetime | None:
    raw = entry.get("published") or entry.get("updated") or entry.get("created")
    if not raw:
        return None
    try:
        dt = parsedate_to_datetime(raw)
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        return dt.astimezone(timezone.utc)
    except Exception:
        return None


def _fetch_rss(topic: str = "", limit: int = DEFAULT_LIMIT, hours: int = DEFAULT_HOURS) -> list[dict]:
    now = datetime.now(timezone.utc)
    cutoff = now.timestamp() - max(1, hours) * 3600
    topic_terms = [x.lower() for x in re.findall(r"\w+", topic or "") if len(x) > 2]
    rows: list[dict] = []
    seen_urls: set[str] = set()

    for source, feed_url in RSS_FEEDS:
        try:
            feed = feedparser.parse(feed_url)
            for entry in feed.entries[:20]:
                title = _clean_html(entry.get("title", ""))
                url = entry.get("link", "")
                if not title or not url or url in seen_urls:
                    continue

                summary = _clean_html(
                    entry.get("summary")
                    or entry.get("description")
                    or ""
                )[:MAX_SUMMARY_CHARS]

                dt = _parse_date(entry)
                if dt and dt.timestamp() < cutoff:
                    continue

                haystack = f"{title} {summary}".lower()
                if topic_terms and not any(term in haystack for term in topic_terms):
                    continue

                seen_urls.add(url)
                rows.append({
                    "title": title,
                    "source": source,
                    "url": url,
                    "published": dt.isoformat() if dt else "",
                    "summary": summary,
                    "method": "RSS",
                })
        except Exception as exc:
            print(f"[AI News] RSS failed: {source}: {exc}")

    rows.sort(key=lambda x: x.get("published", ""), reverse=True)
    return rows[:limit]


def _web_news(topic: str, limit: int) -> list[dict]:
    """Use Mark-LIII's existing DDGS news capability."""
    try:
        from actions.web_search import _ddg_news

        results = _ddg_news(topic or "artificial intelligence", max_results=limit)
        out = []
        for item in results or []:
            out.append({
                "title": _clean_html(item.get("title", "")),
                "source": item.get("source", "") or "Web News",
                "url": item.get("url", ""),
                "published": item.get("date", "") or "",
                "summary": _clean_html(item.get("snippet", ""))[:MAX_SUMMARY_CHARS],
                "method": "Web Search",
            })
        return [x for x in out if x["title"] and x["url"]]
    except Exception as exc:
        print(f"[AI News] Web search failed: {exc}")
        return []


def _dedupe(items: list[dict], limit: int) -> list[dict]:
    out = []
    seen_keys = set()

    for item in items:
        key = (
            re.sub(r"[^a-z0-9]+", " ", item.get("title", "").lower()).strip()
            or item.get("url", "")
        )
        if key in seen_keys:
            continue
        seen_keys.add(key)
        out.append(item)
        if len(out) >= limit:
            break

    return out


def _get_gemini_summary(items: list[dict], topic: str) -> str:
    api_key = get_gemini_key()
    if not api_key:
        return "Gemini summary unavailable because the Mark-LIII Gemini API key is not configured."

    try:
        from google import genai

        client = genai.Client(api_key=api_key)

        source_text = []
        for i, item in enumerate(items, 1):
            source_text.append(
                f"""ARTICLE {i}
Title: {item.get('title', '')}
Source: {item.get('source', '')}
Published: {item.get('published', '')}
URL: {item.get('url', '')}
Summary: {item.get('summary', '')[:MAX_ARTICLE_CHARS]}
"""
            )

        prompt = f"""
You are JARVIS's AI News Intelligence analyst.

Topic: {topic or "Artificial Intelligence"}

Analyze the current news items below.

Rules:
- Do not invent facts.
- Use only the supplied article information.
- Preserve source attribution.
- Do not fabricate URLs.
- Distinguish facts from implications.
- Prioritize material developments over hype.
- If an article appears duplicate or low-value, deprioritize it.

Return:
1. A concise executive briefing in the user's language.
2. The 3-5 most important developments.
3. For each: WHAT HAPPENED, WHY IT MATTERS, and IMPACT.
4. A final "WATCH NEXT" section.
5. Keep each source URL exactly as supplied when citing an article.

NEWS ITEMS:
{chr(10).join(source_text)}
"""

        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=prompt,
        )
        text = (response.text or "").strip()
        if not text:
            return "Gemini returned an empty news analysis."
        return text
    except Exception as exc:
        print(f"[AI News] Gemini summarization failed: {exc}")
        return f"News was collected successfully, but Gemini summarization failed: {exc}"


def _format_sources(items: list[dict]) -> str:
    lines = ["SOURCES"]
    for idx, item in enumerate(items, 1):
        published = item.get("published") or "date unavailable"
        lines.append(
            f"{idx}. {item.get('title', 'Untitled')} — "
            f"{item.get('source', 'Unknown source')} — {published}\n"
            f"   {item.get('url', '')}"
        )
    return "\n".join(lines)


def _briefing(topic: str, limit: int, hours: int) -> str:
    rss_items = _fetch_rss(topic=topic, limit=limit, hours=hours)

    # Web search supplements RSS rather than replacing it.
    search_topic = topic.strip() if topic.strip() else "artificial intelligence"
    web_items = _web_news(search_topic, limit=max(4, limit // 2))

    items = _dedupe(rss_items + web_items, limit=limit)

    if not items:
        return "I could not find current AI news from the configured RSS feeds or web news search."

    analysis = _get_gemini_summary(items, topic or "Artificial Intelligence")

    return (
        f"{analysis}\n\n"
        f"{_format_sources(items)}"
    )


def run(parameters: dict, player=None, session_memory=None) -> str:
    action = str(parameters.get("action", "briefing") or "briefing").strip().lower()
    topic = str(parameters.get("topic", "") or "").strip()
    limit = parameters.get("limit", DEFAULT_LIMIT)
    hours = parameters.get("hours", DEFAULT_HOURS)

    try:
        limit = max(1, min(int(limit), MAX_LIMIT))
    except Exception:
        limit = DEFAULT_LIMIT

    try:
        hours = max(1, min(int(hours), 168))
    except Exception:
        hours = DEFAULT_HOURS

    try:
        if action == "monitor_add":
            if not topic:
                return "Please specify the AI topic to monitor."
            return add_monitor(topic)

        if action == "monitor_remove":
            if not topic:
                return "Please specify the monitored topic to remove."
            return remove_monitor(topic)

        if action == "monitor_list":
            topics = list_monitors()
            if not topics:
                return "No background news topics are currently being monitored."
            return "Currently monitored topics: " + "; ".join(topics)

        result = _briefing(topic, limit, hours)

        if player:
            try:
                player.write_log(f"JARVIS AI NEWS: {result[:1200]}")
            except Exception:
                pass

        return result

    except Exception as exc:
        print(f"[AI News] Plugin error: {exc}")
        return f"Sir, the AI News plugin failed: {exc}"
