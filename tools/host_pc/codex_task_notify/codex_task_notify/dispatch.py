from __future__ import annotations


EVENT_PRIORITIES = {
    "success": "3",
    "failure": "5",
    "manual-attention": "4",
    "long-run-finished": "4",
}


def format_event_title(title_prefix: str, event_type: str) -> str:
    return f"{title_prefix}: {event_type}"


def dispatch_event(
    provider,
    title_prefix: str,
    event_type: str,
    message: str,
    toast_enabled: bool,
    toast_sender=None,
) -> None:
    title = format_event_title(title_prefix, event_type)
    priority = EVENT_PRIORITIES[event_type]
    provider.send(title=title, body=message, priority=priority)
    if not toast_enabled or toast_sender is None:
        return
    try:
        toast_sender(title=title, body=message)
    except Exception:
        return
