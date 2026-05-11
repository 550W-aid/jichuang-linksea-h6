from __future__ import annotations

import argparse
import sys

from codex_task_notify.config import NotifyConfig, load_config, write_config
from codex_task_notify.dispatch import EVENT_PRIORITIES, dispatch_event
from codex_task_notify.providers import NtfyProvider
from codex_task_notify.runner import run_wrapped_command
from codex_task_notify.toast import send_windows_toast


EVENT_TYPES = tuple(EVENT_PRIORITIES.keys())


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Codex task completion notifier")
    subparsers = parser.add_subparsers(dest="command", required=True)

    init_parser = subparsers.add_parser("init", help="Write initial notification config")
    init_parser.add_argument("--server", required=True)
    init_parser.add_argument("--topic", required=True)
    init_parser.add_argument("--title-prefix", default="Codex")
    init_parser.add_argument("--long-run-minutes", type=float, default=15.0)
    init_parser.add_argument("--desktop-toast", choices=("on", "off"), default="on")

    event_parser = subparsers.add_parser("event", help="Send one explicit notification event")
    event_parser.add_argument("--type", choices=EVENT_TYPES, required=True)
    event_parser.add_argument("--message", required=True)

    run_parser = subparsers.add_parser("run", help="Run a command and send lifecycle notifications")
    run_parser.add_argument("run_command", nargs=argparse.REMAINDER)

    subparsers.add_parser("test", help="Send a test notification")
    return parser.parse_args(argv)


def build_provider(config: NotifyConfig) -> NtfyProvider:
    return NtfyProvider(
        server=config.server,
        topic=config.topic,
        token=config.token,
    )


def handle_init(args: argparse.Namespace) -> int:
    topic = args.topic.strip()
    if not topic:
        raise SystemExit("--topic must not be empty")

    config = NotifyConfig(
        provider="ntfy",
        server=args.server,
        topic=topic,
        token=None,
        title_prefix=args.title_prefix,
        long_run_minutes=args.long_run_minutes,
        desktop_toast=args.desktop_toast == "on",
    )
    path = write_config(config)
    print(path)
    return 0


def handle_event(args: argparse.Namespace) -> int:
    config = load_config()
    provider = build_provider(config)
    dispatch_event(
        provider=provider,
        title_prefix=config.title_prefix,
        event_type=args.type,
        message=args.message,
        toast_enabled=config.desktop_toast,
        toast_sender=send_windows_toast,
    )
    return 0


def handle_run(args: argparse.Namespace) -> int:
    if not args.run_command:
        raise SystemExit("run requires a command after --")
    command = list(args.run_command)
    if command[0] == "--":
        command = command[1:]
    if not command:
        raise SystemExit("run requires a command after --")

    config = load_config()
    provider = build_provider(config)

    def dispatch(event_type: str, message: str) -> None:
        dispatch_event(
            provider=provider,
            title_prefix=config.title_prefix,
            event_type=event_type,
            message=message,
            toast_enabled=config.desktop_toast,
            toast_sender=send_windows_toast,
        )

    return run_wrapped_command(command, dispatch, config.long_run_minutes)


def handle_test() -> int:
    config = load_config()
    provider = build_provider(config)
    dispatch_event(
        provider=provider,
        title_prefix=config.title_prefix,
        event_type="success",
        message="Test notification from codex task notify",
        toast_enabled=config.desktop_toast,
        toast_sender=send_windows_toast,
    )
    return 0


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv if argv is not None else sys.argv[1:])
    if args.command == "init":
        return handle_init(args)
    if args.command == "event":
        return handle_event(args)
    if args.command == "run":
        return handle_run(args)
    if args.command == "test":
        return handle_test()
    raise AssertionError(f"Unhandled command: {args.command}")


if __name__ == "__main__":
    raise SystemExit(main())
