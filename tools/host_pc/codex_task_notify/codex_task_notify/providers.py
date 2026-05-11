from __future__ import annotations

from urllib.request import Request, urlopen


class NtfyProvider:
    def __init__(self, server: str, topic: str, token: str | None):
        self.server = server.rstrip("/")
        self.topic = topic
        self.token = token

    def send(self, title: str, body: str, priority: str) -> None:
        request = Request(
            f"{self.server}/{self.topic}",
            data=body.encode("utf-8"),
            method="POST",
            headers={
                "Title": title,
                "Priority": priority,
            },
        )
        if self.token:
            request.add_header("Authorization", f"Bearer {self.token}")
        with urlopen(request, timeout=10):
            return
