"""Tests for the licence gate.

Run from the repository root:
python3 -m unittest discover -s tools/tests -t tools
"""

from __future__ import annotations

import contextlib
import hashlib
import io
import json
import tempfile
import unittest
from pathlib import Path

import license_gate

PHOTO_BYTES = b"not really a photo, but it hashes just the same"
PHOTO_SHA256 = hashlib.sha256(PHOTO_BYTES).hexdigest()

CLIP_BYTES = b"not really a recording either"
CLIP_SHA256 = hashlib.sha256(CLIP_BYTES).hexdigest()

CLIP_FILE = "speech/quiz.prompt.whereIs/amsel.m4a"


def media(**overrides) -> dict:
    """A valid media object, with the given fields replaced or removed.

    A field set to None is removed, which is how the tests express "missing".
    """
    asset = {
        "file": "photos/amsel.jpg",
        "sha256": PHOTO_SHA256,
        "license": "CC-BY-4.0",
        "attribution": "Alexis Tinker-Tsavalas",
        "sourceURL": "https://www.inaturalist.org/observations/1",
    }
    asset.update(overrides)
    return {key: value for key, value in asset.items() if value is not None}


def bird(**overrides) -> dict:
    """A valid bird entry, with the given fields replaced or removed."""
    entry = {
        "id": "amsel",
        "name": "Amsel",
        "scientificName": "Turdus merula",
        "taxonID": 12716,
        "article": "die",
        "photo": media(),
    }
    entry.update(overrides)
    return {key: value for key, value in entry.items() if value is not None}


def clip(**overrides) -> dict:
    """A valid speech clip — three fields and no licence of its own."""
    entry = {"file": CLIP_FILE, "sha256": CLIP_SHA256, "text": "Wo ist die Amsel?"}
    entry.update(overrides)
    return {key: value for key, value in entry.items() if value is not None}


def voice(**overrides) -> dict:
    """A valid voice block — a medium's licence fields without the file."""
    block = {
        "license": "CC-BY-4.0",
        "attribution": "Stimme: Johanna",
        "sourceURL": "https://example.org/docs/sprachaufnahmen.md",
        "retrieved": "2026-09-12",
    }
    block.update(overrides)
    return {key: value for key, value in block.items() if value is not None}


class LicenseGateTestCase(unittest.TestCase):
    """Base class providing a throwaway packs directory."""

    def setUp(self) -> None:
        self._directory = tempfile.TemporaryDirectory()
        self.addCleanup(self._directory.cleanup)
        root = Path(self._directory.name)

        # Two directories, as the repository has them. The fixed sentences sit
        # outside data/packs on purpose — they carry no birds — so a test must
        # not be able to reach them through the pack directory's rglob.
        self.packs_dir = root / "packs"
        self.packs_dir.mkdir()
        self.speech_dir = root / "speech"

    def write_manifest(self, document, name: str = "basis.json") -> Path:
        path = self.packs_dir / name
        path.write_text(json.dumps(document), encoding="utf-8")
        return path

    def write_asset(self, relative: str, content: bytes) -> Path:
        """Write one file where a manifest in the packs directory names it."""
        path = self.packs_dir / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
        return path

    def write_photo(self, relative: str = "photos/amsel.jpg", content: bytes = PHOTO_BYTES) -> Path:
        return self.write_asset(relative, content)

    def write_pack(self, **photo_fields) -> Path:
        """Write the local photo plus a one-bird manifest whose photo carries `photo_fields`."""
        self.write_photo()
        return self.write_manifest({"id": "basis", "birds": [bird(photo=media(**photo_fields))]})

    def write_clip(self, relative: str = CLIP_FILE, content: bytes = CLIP_BYTES) -> Path:
        return self.write_asset(relative, content)

    def write_speech_manifest(self, document) -> Path:
        """Write the manifest of the sentences that belong to no pack."""
        self.speech_dir.mkdir(parents=True, exist_ok=True)
        path = self.speech_dir / "manifest.json"
        path.write_text(json.dumps(document), encoding="utf-8")
        return path

    def run_gate(self, packs_dir: Path | None = None) -> tuple[int, str]:
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            code = license_gate.main(
                [str(packs_dir or self.packs_dir), "--speech-dir", str(self.speech_dir)]
            )
        return code, output.getvalue()

    def assertPasses(self) -> str:
        code, output = self.run_gate()
        self.assertEqual(code, 0, output)
        self.assertNotIn("::error", output)
        return output

    def assertFails(self, *expected_fragments: str) -> str:
        code, output = self.run_gate()
        self.assertEqual(code, 1, output)
        self.assertIn("::error", output)
        for fragment in expected_fragments:
            self.assertIn(fragment, output)
        return output


class ValidManifestTests(LicenseGateTestCase):
    def test_valid_manifest_with_local_file_passes(self):
        self.write_pack()

        output = self.assertPasses()
        self.assertIn("Licence gate passed", output)

    def test_every_allowed_licence_passes(self):
        for licence in license_gate.ALLOWED_LICENCES:
            with self.subTest(licence=licence):
                self.write_pack(license=licence)
                self.assertPasses()

    def test_absent_call_is_fine(self):
        self.write_pack()

        output = self.assertPasses()
        self.assertIn("media assets checked: 1", output)

    def test_null_call_is_fine(self):
        # How the manifest schema spells "no recording yet": the key is there
        # and holds null, not absent. bird() drops None values, so the null
        # has to be put in afterwards.
        self.write_photo()
        entry = bird()
        entry["call"] = None
        self.write_manifest({"id": "basis", "birds": [entry]})

        output = self.assertPasses()
        self.assertIn("media assets checked: 1", output)

    def test_present_call_is_checked_too(self):
        self.write_photo()
        self.write_manifest(
            {"birds": [bird(call=media(file="calls/amsel.mp3", license="CC-BY-NC-SA-4.0"))]}
        )

        self.assertFails("amsel / call", "CC-BY-NC-SA-4.0")

    def test_manifest_in_a_pack_subdirectory_is_checked(self):
        # rglob: a pack with its own directory must not escape the gate.
        nested = self.packs_dir / "deutschland"
        nested.mkdir()
        (nested / "birds.json").write_text(
            json.dumps({"birds": [bird(photo=media(license="CC-BY-NC-4.0"))]}), encoding="utf-8"
        )

        self.assertFails("deutschland", "CC-BY-NC-4.0")

    def test_empty_packs_directory_passes_with_a_notice(self):
        code, output = self.run_gate()

        self.assertEqual(code, 0, output)
        self.assertIn("::notice::", output)


class LicenceRuleTests(LicenseGateTestCase):
    def test_disallowed_licences_fail(self):
        for licence in ("CC-BY-NC-4.0", "CC-BY-ND-4.0", "CC-BY-NC-SA-4.0", "CC-BY"):
            with self.subTest(licence=licence):
                self.write_pack(license=licence)

                output = self.assertFails("basis.json", "amsel / photo", licence)
                self.assertIn("is not permitted", output)

    def test_missing_licence_fails(self):
        self.write_pack(license=None)

        self.assertFails("'license' is missing or empty")

    def test_empty_attribution_fails(self):
        self.write_pack(attribution="   ")

        self.assertFails("'attribution' is missing or empty")

    def test_missing_attribution_fails(self):
        self.write_pack(attribution=None)

        self.assertFails("'attribution' is missing or empty")

    def test_missing_source_url_fails(self):
        self.write_pack(sourceURL=None)

        self.assertFails("'sourceURL' is missing or empty")

    def test_missing_file_field_fails(self):
        self.write_pack(file=None)

        self.assertFails("'file' is missing or empty")

    def test_missing_photo_fails(self):
        self.write_manifest({"birds": [bird(photo=None)]})

        self.assertFails("'photo' is missing")

    def test_null_photo_fails(self):
        # A null photo is as missing as an absent one — only the call may be null.
        entry = bird()
        entry["photo"] = None
        self.write_manifest({"birds": [entry]})

        self.assertFails("'photo' is missing")


class HashTests(LicenseGateTestCase):
    def test_sha256_mismatch_fails(self):
        self.write_photo(content=b"a different photo entirely")
        self.write_manifest({"birds": [bird()]})

        self.assertFails("sha256 does not match")

    def test_missing_sha256_fails_when_the_file_is_present(self):
        self.write_pack(sha256=None)

        self.assertFails("'sha256' is missing or empty")

    def test_missing_sha256_fails_for_s3_only_assets_too(self):
        # The Pack model declares sha256 non-optional and the downloader
        # verifies it — an asset without a declared hash must not pass.
        self.write_manifest({"birds": [bird(photo=media(sha256=None))]})

        self.assertFails("'sha256' is missing or empty")

    def test_absent_file_skips_the_hash_check(self):
        # No write_pack here on purpose: the asset lives in S3 only, so there is
        # nothing to hash — a wrong sha256 cannot be caught and must not fail.
        self.write_manifest({"birds": [bird(photo=media(sha256="deadbeef"))]})

        self.assertPasses()

    def test_absent_file_still_has_its_metadata_checked(self):
        # S3-only again: the hash is skipped, the licence is not.
        self.write_manifest({"birds": [bird(photo=media(license="CC-BY-NC-4.0"))]})

        self.assertFails("amsel / photo", "CC-BY-NC-4.0")


class SpeechInAPackTests(LicenseGateTestCase):
    """A pack's species sentences: clips under the bird, licence at the top."""

    def write_speaking_pack(self, speech=None, **document_fields) -> Path:
        """A one-bird pack whose bird carries one clip, with the voice above it."""
        self.write_photo()
        self.write_clip()
        document = {
            "id": "basis",
            "voice": voice(),
            "birds": [bird(speech=speech if speech is not None else {"quiz.prompt.whereIs": clip()})],
        }
        document.update(document_fields)
        return self.write_manifest({key: value for key, value in document.items() if value is not None})

    def test_a_voice_and_a_clip_pass(self):
        self.write_speaking_pack()

        output = self.assertPasses()
        # The photo and the clip — a speech clip is a medium like any other.
        self.assertIn("media assets checked: 2", output)

    def test_speech_without_a_voice_fails(self):
        self.write_speaking_pack(voice=None)

        self.assertFails("basis.json", "carries no 'voice'")

    def test_a_clip_without_text_fails(self):
        self.write_speaking_pack(speech={"quiz.prompt.whereIs": clip(text=None)})

        self.assertFails("amsel / speech / quiz.prompt.whereIs", "'text' is missing or empty")

    def test_a_clip_whose_hash_is_wrong_fails(self):
        self.write_speaking_pack(speech={"quiz.prompt.whereIs": clip(sha256="0" * 64)})

        self.assertFails("amsel / speech / quiz.prompt.whereIs", "sha256 does not match")

    def test_a_clip_that_is_only_in_the_bucket_skips_the_hash(self):
        self.write_speaking_pack(speech={"collection.name": clip(file="speech/collection.name/amsel.m4a")})

        self.assertPasses()

    def test_a_clip_that_is_not_an_object_fails(self):
        self.write_speaking_pack(speech={"quiz.prompt.whereIs": "speech/amsel.m4a"})

        self.assertFails("amsel / speech / quiz.prompt.whereIs: is not an object")

    def test_a_speech_block_that_is_not_an_object_fails(self):
        self.write_speaking_pack(speech=["quiz.prompt.whereIs"])

        self.assertFails("amsel / speech: is not an object")

    def test_a_pack_without_speech_needs_no_voice(self):
        # What every pack looks like today, and has to keep looking like.
        self.write_pack()

        self.assertPasses()


class VoiceTests(LicenseGateTestCase):
    """The voice is checked exactly as a medium is, minus the file."""

    def write_voice(self, **fields) -> Path:
        self.write_photo()
        self.write_clip()
        return self.write_manifest(
            {
                "id": "basis",
                "voice": voice(**fields),
                "birds": [bird(speech={"quiz.prompt.whereIs": clip()})],
            }
        )

    def test_a_disallowed_licence_fails(self):
        self.write_voice(license="CC-BY-NC-4.0")

        self.assertFails("voice", "CC-BY-NC-4.0", "is not permitted")

    def test_a_missing_attribution_fails(self):
        self.write_voice(attribution=None)

        self.assertFails("voice: field 'attribution' is missing or empty")

    def test_a_missing_source_url_fails(self):
        self.write_voice(sourceURL=None)

        self.assertFails("voice: field 'sourceURL' is missing or empty")

    def test_a_voice_without_clips_is_checked_all_the_same(self):
        self.write_photo()
        self.write_manifest({"id": "basis", "voice": voice(license="CC-BY-ND-4.0"), "birds": [bird()]})

        self.assertFails("voice", "CC-BY-ND-4.0")

    def test_a_voice_that_is_not_an_object_fails(self):
        self.write_photo()
        self.write_manifest({"id": "basis", "voice": "Johanna", "birds": [bird()]})

        self.assertFails("voice: is not an object")


class FixedSentenceTests(LicenseGateTestCase):
    """data/speech/manifest.json — the sentences that belong to no pack."""

    def write_lines(self, lines, **document_fields) -> Path:
        document = {"id": "speech", "title": "Ansagen", "voice": voice(), "lines": lines}
        document.update(document_fields)
        return self.write_speech_manifest(
            {key: value for key, value in document.items() if value is not None}
        )

    def write_line_file(self, relative: str = "roundEnd.title.m4a") -> Path:
        self.speech_dir.mkdir(parents=True, exist_ok=True)
        path = self.speech_dir / relative
        path.write_bytes(CLIP_BYTES)
        return path

    def test_a_voice_and_a_line_pass(self):
        self.write_lines({"roundEnd.title": clip(file="roundEnd.title.m4a", text="Super gemacht!")})
        self.write_line_file()

        output = self.assertPasses()
        self.assertIn("media assets checked: 1", output)

    def test_lines_without_a_voice_fail_naming_the_manifest(self):
        self.write_lines({"roundEnd.title": clip(file="roundEnd.title.m4a")}, voice=None)

        self.assertFails("manifest.json", "carries no 'voice'")

    def test_an_empty_manifest_needs_no_voice(self):
        # What ships today: the directory exists, nobody has recorded anything,
        # and there is nobody to credit.
        self.write_lines({}, voice=None)

        self.assertPasses()

    def test_a_line_whose_hash_is_wrong_fails(self):
        self.write_lines({"roundEnd.title": clip(file="roundEnd.title.m4a", sha256="0" * 64)})
        self.write_line_file()

        self.assertFails("lines / roundEnd.title", "sha256 does not match")

    def test_a_manifest_without_lines_fails(self):
        self.write_speech_manifest({"id": "speech", "title": "Ansagen"})

        self.assertFails("no lines found")

    def test_a_missing_speech_directory_is_fine(self):
        self.write_pack()

        self.assertPasses()

    def test_a_lines_manifest_below_data_packs_fails_as_a_pack(self):
        # The shape does not decide which gate applies, the location does —
        # otherwise a manifest without birds would slip through data/packs.
        self.write_manifest({"id": "speech", "lines": {"roundEnd.title": clip()}})

        self.assertFails("no birds found")


class ManifestShapeTests(LicenseGateTestCase):
    def test_malformed_json_fails(self):
        (self.packs_dir / "basis.json").write_text("{ this is not json", encoding="utf-8")

        self.assertFails("cannot be read")

    def test_manifest_without_a_birds_list_fails(self):
        self.write_manifest({"id": "basis", "title": "Basis"})

        self.assertFails("no birds found")

    def test_bare_array_manifest_fails(self):
        self.write_manifest([bird()])

        self.assertFails("no birds found")

    def test_bird_that_is_not_an_object_fails(self):
        self.write_manifest({"birds": ["amsel"]})

        self.assertFails("bird #1: is not an object")

    def test_non_object_photo_fails_and_is_not_counted(self):
        self.write_manifest({"birds": [bird(photo="photos/amsel.jpg")]})

        output = self.assertFails("photo: is not an object")
        self.assertIn("media assets checked: 0", output)

    def test_annotation_data_is_escaped(self):
        # A newline in manifest data must not split the ::error annotation.
        self.write_pack(license="CC-BY-NC\n4.0")

        output = self.assertFails("CC-BY-NC%0A4.0")
        for line in output.splitlines():
            if line.startswith("::error"):
                self.assertIn("%0A", line)

    def test_bird_without_id_is_named_by_position(self):
        self.write_manifest({"birds": [bird(id=None, photo=media(license="CC-BY-NC-4.0"))]})

        self.assertFails("bird #1 / photo")

    def test_missing_packs_directory_fails(self):
        code, output = self.run_gate(self.packs_dir / "nowhere")

        self.assertEqual(code, 1, output)
        self.assertIn("::error::Pack directory not found", output)


if __name__ == "__main__":
    unittest.main()
