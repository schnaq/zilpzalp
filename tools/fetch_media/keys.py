"""The API keys this tool reads, and the one place that keeps them out of text.

Every key comes from the environment, where `infisical run --env=dev --path=/
--` puts it. None is ever written down here, in a fixture or in a test, and
none is ever printed: `cli.main` sends every failure through `redact` before it
becomes an `::error::` line that CI keeps in its log.

There are two ways a key ends up in a message, and `redact` closes both:

- **as a query parameter.** xeno-canto takes its key in the URL, and
  `httpx.HTTPStatusError` puts the request URL into its message.
- **as itself.** A vendor that takes its key in a header can still echo it in
  an error body, and a `KeyError` or a badly written adapter can hand it
  straight to a formatter. Any value the environment holds under one of
  `NAMES` is therefore replaced wherever it appears.

`ELEVENLABS_API_KEY` is what the speech provider reads
(docs/superpowers/plans/2026-09-08-recorded-speech.md, decision 2, and issue
#221). It travels as the `xi-api-key` header rather than in a URL, which is
exactly the second case above: an error body that echoes it would otherwise
reach a CI log.
"""

from __future__ import annotations

import os
import re

XENO_CANTO = "XENO_CANTO_API_KEY"
ELEVENLABS = "ELEVENLABS_API_KEY"

NAMES = (XENO_CANTO, ELEVENLABS)

# `key=…` in a URL, up to the next separator.
IN_A_URL = re.compile(r"(?i)(key=)[^&\s'\"]+")

REPLACEMENT = "…"

# Shorter than this and a value is not a key but a placeholder someone put in
# an environment to see what happens — and blanking every occurrence of `x`
# would make the message it appears in unreadable.
SHORTEST = 8


def redact(text: str, environment: dict | None = None) -> str:
    """Remove every API key from anything that might be printed."""
    environment = os.environ if environment is None else environment

    redacted = IN_A_URL.sub(rf"\1{REPLACEMENT}", text)
    for name in NAMES:
        value = environment.get(name)
        if value and len(value) >= SHORTEST:
            redacted = redacted.replace(value, REPLACEMENT)
    return redacted


def api_key(name: str, environment: dict | None = None) -> str:
    """The key of that name, from the environment Infisical fills.

    Raises `RuntimeError` naming the *variable* that is missing — never its
    value, exactly as `s3.client_from_env` does for the bucket credentials.
    """
    environment = os.environ if environment is None else environment
    key = environment.get(name)
    if not key:
        raise RuntimeError(
            f"missing from the environment: {name}. "
            "Run through 'infisical run --env=dev --path=/ --'."
        )
    return key
