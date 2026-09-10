# JARVIS AI News Intelligence patch

Files:
- plugins/ai_news.py — drop-in plugin
- requirements.txt — Mark-LIII requirements with feedparser added
- core/prompt_ai_news_addition.txt — append to core/prompt.txt

Integration:
1. Copy plugins/ai_news.py into Mark-LIII/plugins/
2. Add feedparser>=6.0.11 to requirements.txt (or replace requirements.txt with the supplied one)
3. Append core/prompt_ai_news_addition.txt to core/prompt.txt
4. Run: python -m pip install -r requirements.txt
5. Start: python main.py

The plugin uses Mark-LIII's existing Gemini API key config and existing DDGS news helper.
Background topic storage uses Mark-LIII's existing background_monitor memory.
