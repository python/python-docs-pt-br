"""Format sphinx-lint diagnostics for the translation team's Telegram alert."""

import os
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import quote


def main(log, output):
    repo = os.environ["PYDOC_REPO"].rstrip("/")
    run = os.environ["GITHUB_RUN_ID"]
    version = os.environ["PYDOC_VERSION"]
    checkout = Path("cpython/Doc/locales") / os.environ["PYDOC_LANGUAGE"] / "LC_MESSAGES"
    revision = subprocess.check_output(
        ["git", "-C", str(checkout), "rev-parse", "HEAD"], universal_newlines=True
    ).strip()
    header = f"❌ *{version} lint* ([execução {run}]({repo}/actions/runs/{run}))"
    footer = "Mais diagnósticos no log da execução."
    message = header
    found = False
    for line in sorted(set(log.read_text(encoding="utf-8").splitlines())):
        match = re.fullmatch(r"(.+?\.po):(\d+):\s+(.+\(.*\))", line)
        if not match:
            continue
        found = True
        filename, lineno, diagnostic = match.groups()
        path = Path(filename)
        if path.is_absolute():
            path = path.relative_to(checkout.resolve())
        url = f"{repo}/blob/{revision}/{quote(path.as_posix())}#L{lineno}"
        detail = f"{path}:{lineno}: {diagnostic}".replace("`", "\\`")
        block = f"\n\n```\n{detail}\n```\n[Abrir linha {lineno}]({url})"
        # Count the unparsed text conservatively, including Markdown and emoji.
        if len((message + block + "\n\n" + footer).encode("utf-16-le")) // 2 > 4096:
            message += "\n\n" + footer
            break
        message += block
    if not found:
        sys.exit("No sphinx-lint diagnostics found")
    output.write_text(message, encoding="utf-8")


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]))
