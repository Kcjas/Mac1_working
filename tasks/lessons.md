# Lessons Learned

| Date | What went wrong | Rule to prevent it |
|------|-----------------|-------------------|
| 2026-03-16 | Initial setup | Always verify project structure before starting. |
| 2026-03-16 | UI syntax & type errors | Never pass CardTheme to ThemeData(cardTheme:), use CardThemeData. InkWell isn't a Container, so decoration/padding need a separate wrapping or inner widget. |
| 2026-06-08 | "Not authenticated" on /worker_info from a stale uvicorn worker still enforcing auth that had been reverted off disk (only surviving as in-memory bytecode; not in git/history/.pyc). | A long-lived `uvicorn --reload` worker can keep serving code that no longer exists on disk. When the live server's behaviour contradicts the source, fully kill the process tree (reloader + workers) and relaunch before debugging further. Verify live route behaviour via `/openapi.json`, not just the files. |
