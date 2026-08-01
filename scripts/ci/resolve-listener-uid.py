#!/usr/bin/env python3
"""Resolve the effective UID of the process listening on a TCP port."""

from __future__ import annotations

import argparse
import os
import re
import socket
import sys
from pathlib import Path

PROC_ROOT = Path("/proc")
LISTEN_STATE = "0A"
SOCKET_LINK = re.compile(r"^socket:\[(?P<inode>[0-9]+)\]$")


class ResolutionError(RuntimeError):
    """Raised when a listener cannot be resolved unambiguously."""


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


def listener_inodes(
    port: int,
    proc_root: Path = PROC_ROOT,
) -> set[str]:
    inodes: set[str] = set()

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
            inode = fields[9]

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

            if (
                state == LISTEN_STATE
                and local_port == port
                and inode != "0"
            ):
                inodes.add(inode)

    return inodes


def effective_uid(process_dir: Path) -> int | None:
    status_path = process_dir / "status"

    try:
        lines = status_path.read_text(
            encoding="ascii"
        ).splitlines()
    except (
        FileNotFoundError,
        PermissionError,
        ProcessLookupError,
    ):
        return None
    except OSError:
        return None

    for line in lines:
        if not line.startswith("Uid:"):
            continue

        fields = line.split()
        if len(fields) < 3:
            raise ResolutionError(
                f"malformed UID record in {status_path}"
            )

        try:
            return int(fields[2], 10)
        except ValueError as error:
            raise ResolutionError(
                f"invalid effective UID in {status_path}: "
                f"{fields[2]!r}"
            ) from error

    raise ResolutionError(
        f"missing UID record in {status_path}"
    )


def listener_owners(
    port: int,
    proc_root: Path = PROC_ROOT,
) -> dict[int, int]:
    inodes = listener_inodes(port, proc_root)
    if not inodes:
        raise ResolutionError(
            f"no TCP LISTEN socket found for port {port}"
        )

    owners: dict[int, int] = {}

    try:
        process_dirs = sorted(
            (
                entry
                for entry in proc_root.iterdir()
                if entry.name.isdecimal() and entry.is_dir()
            ),
            key=lambda entry: int(entry.name),
        )
    except OSError as error:
        raise ResolutionError(
            f"cannot enumerate {proc_root}: {error}"
        ) from error

    for process_dir in process_dirs:
        fd_dir = process_dir / "fd"

        try:
            file_descriptors = list(fd_dir.iterdir())
        except (
            FileNotFoundError,
            PermissionError,
            ProcessLookupError,
        ):
            continue
        except OSError:
            continue

        owns_listener = False

        for file_descriptor in file_descriptors:
            try:
                target = os.readlink(file_descriptor)
            except (
                FileNotFoundError,
                PermissionError,
                ProcessLookupError,
            ):
                continue
            except OSError:
                continue

            match = SOCKET_LINK.fullmatch(target)
            if (
                match
                and match.group("inode") in inodes
            ):
                owns_listener = True
                break

        if not owns_listener:
            continue

        uid = effective_uid(process_dir)
        if uid is not None:
            owners[int(process_dir.name)] = uid

    if not owners:
        joined_inodes = ", ".join(
            sorted(inodes, key=int)
        )
        raise ResolutionError(
            "listener socket inode(s) "
            f"{joined_inodes} have no readable process owner"
        )

    return owners


def resolve_single_owner(
    port: int,
    proc_root: Path = PROC_ROOT,
) -> tuple[int, int]:
    owners = listener_owners(port, proc_root)

    if len(owners) != 1:
        rendered = ", ".join(
            f"pid={pid} uid={uid}"
            for pid, uid in sorted(owners.items())
        )
        raise ResolutionError(
            "expected exactly one process owner for "
            f"TCP/{port}, found {len(owners)}: {rendered}"
        )

    return next(iter(owners.items()))


def run_self_test() -> None:
    with socket.socket(
        socket.AF_INET,
        socket.SOCK_STREAM,
    ) as listener:
        listener.bind(("127.0.0.1", 0))
        listener.listen(1)

        port = int(listener.getsockname()[1])
        pid, uid = resolve_single_owner(port)

    expected = (os.getpid(), os.geteuid())
    if (pid, uid) != expected:
        raise ResolutionError(
            f"self-test resolved pid={pid} uid={uid}, "
            f"expected pid={expected[0]} uid={expected[1]}"
        )

    print(
        "resolve-listener-uid self-test passed: "
        f"pid={pid} uid={uid}"
    )


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Resolve the single process and effective UID "
            "owning a TCP LISTEN socket."
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
            "/proc resolution"
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

        pid, uid = resolve_single_owner(arguments.port)
    except ResolutionError as error:
        print(
            f"resolve-listener-uid: {error}",
            file=sys.stderr,
        )
        return 1

    print(f"{pid} {uid}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
