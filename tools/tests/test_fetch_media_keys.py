"""Tests for the one place that keeps an API key out of a printed message.

No key of any kind is real here, and none reaches a vendor: the values below
are what a key looks like, not one that opens anything.

Run from the repository root:
uv run --locked --project tools python -m unittest discover -s tools/tests -t tools
"""

from __future__ import annotations

import unittest

from fetch_media import keys

XENO_CANTO_KEY = "0123456789abcdef0123456789abcdef01234567"
SPEECH_KEY = "sk-not-a-real-elevenlabs-key-0123456789"


class RedactTests(unittest.TestCase):
    def test_removes_a_key_from_a_url(self) -> None:
        text = (
            "Client error '401 Unauthorized' for url "
            f"'https://xeno-canto.org/api/3/recordings?query=nr%3A1&key={XENO_CANTO_KEY}'"
        )

        redacted = keys.redact(text, {})

        self.assertNotIn(XENO_CANTO_KEY, redacted)
        self.assertIn("key=…", redacted)
        self.assertIn("query=nr%3A1", redacted)

    def test_removes_a_key_wherever_it_sits_in_a_url(self) -> None:
        for text in (
            f"?key={XENO_CANTO_KEY}&query=nr:1",
            f"?KEY={XENO_CANTO_KEY}",
            f"'https://xeno-canto.org/api/3/recordings?key={XENO_CANTO_KEY}'",
            f"?key={XENO_CANTO_KEY} trailing words",
        ):
            with self.subTest(text=text):
                self.assertNotIn(XENO_CANTO_KEY, keys.redact(text, {}))

    def test_removes_a_key_that_is_not_in_a_url_at_all(self) -> None:
        """A provider that takes its key in a header can still echo it back."""
        environment = {keys.ELEVENLABS: SPEECH_KEY}

        redacted = keys.redact(f"401: the voice API refused {SPEECH_KEY}", environment)

        self.assertNotIn(SPEECH_KEY, redacted)
        self.assertIn("the voice API refused", redacted)

    def test_knows_the_keys_the_speech_adapters_read(self) -> None:
        """An adapter must not be the thing that teaches this — by then it is logged."""
        self.assertIn("ELEVENLABS_API_KEY", keys.NAMES)
        self.assertIn("GOOGLE_TTS_SERVICE_ACCOUNT_JSON", keys.NAMES)

    def test_removes_a_secret_an_adapter_derived_rather_than_read(self) -> None:
        """The Google adapter signs and exchanges; neither result is in an env."""
        token = "ya29.a-token-no-environment-ever-held"

        redacted = keys.redact(f"401: refused {token}", {}, extra=(token, None))

        self.assertNotIn(token, redacted)
        self.assertIn("401: refused", redacted)

    def test_leaves_a_value_too_short_to_be_a_key_alone(self) -> None:
        """Blanking every 'x' would make the message it appears in unreadable."""
        text = "expected x, got y"

        self.assertEqual(keys.redact(text, {keys.ELEVENLABS: "x"}), text)

    def test_leaves_text_without_a_key_alone(self) -> None:
        self.assertEqual(keys.redact("no key here", {}), "no key here")


class ApiKeyTests(unittest.TestCase):
    def test_reads_the_key_from_the_environment(self) -> None:
        self.assertEqual(
            keys.api_key(keys.XENO_CANTO, {keys.XENO_CANTO: XENO_CANTO_KEY}), XENO_CANTO_KEY
        )

    def test_names_the_variable_and_the_command_that_provides_it(self) -> None:
        for name in (keys.XENO_CANTO, keys.ELEVENLABS):
            with self.subTest(name=name), self.assertRaises(RuntimeError) as error:
                keys.api_key(name, {})

            self.assertIn(name, str(error.exception))
            self.assertIn("infisical run", str(error.exception))


if __name__ == "__main__":
    unittest.main()
