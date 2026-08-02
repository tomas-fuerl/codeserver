#!/usr/bin/env python3
"""Resolve the effective UID owning a TCP LISTEN socket."""

from __future__ import annotations

import argparse
import os
import socket
import sys
from pathlib import Path

PROC_ROOT = Path("/proc")
LISTEN_STATE = "0A"


class ResolutionError(RuntimeError):
    """Raised when a listener UID cannot be resolved unambiguously."""


def tcp_port(value: str) -> int:
    try:
        port = int(value, 10)
    except ValueError as error:
        raise argparse.ArgumentTypeError(
            "port must be a decimal integer"
        ) from error

    if not 1 <= port <= 65535:
        raise argparse.ArgumentTypeError(
            "port must be between 1 and 65535"
        )

    return port


def listener_uids(
    port: int,
    proc_root: Path = PROC_ROOT,
) -> set[int]:
    """Return UIDs recorded for LISTEN sockets on the requested port."""

    uids: set[int] = set()
    readable_tables = 0

    for table_name in ("tcp", "tcp6"):
        table_path = proc_root / "net" / table_name

        try:
            lines = table_path.read_text(
                encoding="ascii"
            ).splitlines()
        except FileNotFoundError:
            continue
        except OSError as error:
            raise ResolutionError(
                f"cannot read {table_path}: {error}"
            ) from error

        readable_tables += 1

        for line_number, line in enumerate(lines[1:], start=2):
            fields = line.split()

            if not fields:
                continue

            if len(fields) < 10:
                raise ResolutionError(
                    f"malformed {table_path} line {line_number}: "
                    "expected at least 10 fields"
                )

            local_endpoint = fields[1]
            state = fields[3]
            uid_text = fields[7]

            try:
                _address, port_hex = local_endpoint.rsplit(
                    ":",
                    maxsplit=1,
                )
                local_port = int(port_hex, 16)
            except (ValueError, IndexError) as error:
                raise ResolutionError(
                    f"malformed local endpoint in {table_path} "
                    f"line {line_number}: {local_endpoint!r}"
                ) from error

            if state != LISTEN_STATE or local_port != port:
                continue

            if not uid_text.isdecimal():
                raise ResolutionError(
                    f"invalid listener UID in {table_path} "
                    f"line {line_number}: {uid_text!r}"
                )

            uids.add(int(uid_text, 10))

    if readable_tables == 0:
        raise ResolutionError(
            f"neither {proc_root / 'net/tcp'} nor "
            f"{proc_root / 'net/tcp6'} is readable"
        )

    return uids


def resolve_listener_uid(
    port: int,
    proc_root: Path = PROC_ROOT,
) -> int:
    """Resolve one unambiguous UID for all listeners on a TCP port."""

    uids = listener_uids(port, proc_root)

    if not uids:
        raise ResolutionError(
            f"no TCP LISTEN socket found for port {port}"
        )

    if len(uids) != 1:
        rendered = ", ".join(
            str(uid)
            for uid in sorted(uids)
        )
        raise ResolutionError(
            f"expected exactly one UID for TCP/{port}, "
            f"found {len(uids)}: {rendered}"
        )

    return next(iter(uids))


def run_self_test() -> None:
    with socket.socket(
        socket.AF_INET,
        socket.SOCK_STREAM,
    ) as listener:
        listener.bind(("127.0.0.1", 0))
        listener.listen(1)

        port = int(listener.getsockname()[1])
        resolved_uid = resolve_listener_uid(port)

    expected_uid = os.geteuid()

    if resolved_uid != expected_uid:
        raise ResolutionError(
            f"self-test resolved uid={resolved_uid}, "
            f"expected uid={expected_uid}"
        )

    print(
        "resolve-listener-uid self-test passed: "
        f"uid={resolved_uid}"
    )


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Resolve the effective UID recorded for "
            "a TCP LISTEN socket."
        )
    )
    parser.add_argument(
        "port",
        nargs="?",
        type=tcp_port,
    )
    parser.add_argument(
        "--self-test",
        action="store_true",
        help=(
            "open a temporary listener and validate "
            "/proc socket UID resolution"
        ),
    )

    arguments = parser.parse_args()

    if arguments.self_test and arguments.port is not None:
        parser.error(
            "PORT must not be supplied with --self-test"
        )

    if not arguments.self_test and arguments.port is None:
        parser.error(
            "PORT is required unless --self-test is used"
        )

    return arguments


def main() -> int:
    arguments = parse_arguments()

    try:
        if arguments.self_test:
            run_self_test()
            return 0

        listener_uid = resolve_listener_uid(arguments.port)
    except ResolutionError as error:
        print(
            f"resolve-listener-uid: {error}",
            file=sys.stderr,
        )
        return 1

    print(listener_uid)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
