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


class LicenseGateTestCase(unittest.TestCase):
    """Base class providing a throwaway packs directory."""

    def setUp(self) -> None:
        self._directory = tempfile.TemporaryDirectory()
        self.addCleanup(self._directory.cleanup)
        self.packs_dir = Path(self._directory.name)

    def write_manifest(self, document, name: str = "basis.json") -> Path:
        path = self.packs_dir / name
        path.write_text(json.dumps(document), encoding="utf-8")
        return path

    def write_photo(self, relative: str = "photos/amsel.jpg", content: bytes = PHOTO_BYTES) -> Path:
        path = self.packs_dir / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
        return path

    def write_pack(self, **photo_fields) -> Path:
        """Write the local photo plus a one-bird manifest whose photo carries `photo_fields`."""
        self.write_photo()
        return self.write_manifest({"id": "basis", "birds": [bird(photo=media(**photo_fields))]})

    def run_gate(self, packs_dir: Path | None = None) -> tuple[int, str]:
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            code = license_gate.main([str(packs_dir or self.packs_dir)])
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
