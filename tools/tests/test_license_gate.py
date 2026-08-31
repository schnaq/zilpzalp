"""Tests for the licence gate.

Run from the repository root: python3 -m unittest discover -s tools/tests
"""

from __future__ import annotations

import contextlib
import hashlib
import io
import json
import sys
import tempfile
import unittest
from pathlib import Path

# `unittest discover -s tools/tests` puts this directory on the path, not
# tools/ — so the module under test has to be found explicitly.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import license_gate  # noqa: E402

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


def species(**overrides) -> dict:
    """A valid species entry, with the given fields replaced or removed."""
    bird = {
        "id": "amsel",
        "name": "Amsel",
        "scientificName": "Turdus merula",
        "taxonID": 12716,
        "article": "die",
        "photo": media(),
    }
    bird.update(overrides)
    return {key: value for key, value in bird.items() if value is not None}


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

    def run_gate(self) -> tuple[int, str]:
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            code = license_gate.main([str(self.packs_dir)])
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
        self.write_photo()
        self.write_manifest({"id": "basis", "species": [species()]})

        output = self.assertPasses()
        self.assertIn("hashes verified: 1", output)

    def test_bare_array_of_species_is_accepted(self):
        self.write_photo()
        self.write_manifest([species()])

        self.assertPasses()

    def test_birds_key_is_accepted(self):
        self.write_photo()
        self.write_manifest({"id": "basis", "birds": [species()]})

        self.assertPasses()

    def test_every_allowed_licence_passes(self):
        self.write_photo()
        for licence in license_gate.ALLOWED_LICENCES:
            with self.subTest(licence=licence):
                self.write_manifest({"species": [species(photo=media(license=licence))]})
                self.assertPasses()

    def test_absent_call_is_fine(self):
        self.write_photo()
        self.write_manifest({"species": [species()]})

        output = self.assertPasses()
        self.assertIn("media assets: 1", output)

    def test_present_call_is_checked_too(self):
        self.write_photo()
        self.write_manifest(
            {"species": [species(call=media(file="calls/amsel.mp3", license="CC-BY-NC-SA-4.0"))]}
        )

        self.assertFails("amsel / call", "CC-BY-NC-SA-4.0")

    def test_empty_packs_directory_passes_with_a_notice(self):
        code, output = self.run_gate()

        self.assertEqual(code, 0, output)
        self.assertIn("::notice::", output)


class LicenceRuleTests(LicenseGateTestCase):
    def test_noncommercial_licence_fails(self):
        self.write_photo()
        self.write_manifest({"species": [species(photo=media(license="CC-BY-NC-4.0"))]})

        output = self.assertFails("basis.json", "amsel / photo", "CC-BY-NC-4.0")
        self.assertIn("is not permitted", output)

    def test_noderivatives_licence_fails(self):
        self.write_photo()
        self.write_manifest({"species": [species(photo=media(license="CC-BY-ND-4.0"))]})

        self.assertFails("amsel / photo", "CC-BY-ND-4.0")

    def test_unversioned_licence_fails(self):
        self.write_photo()
        self.write_manifest({"species": [species(photo=media(license="CC-BY"))]})

        self.assertFails("amsel / photo", "CC-BY")

    def test_missing_licence_fails(self):
        self.write_photo()
        self.write_manifest({"species": [species(photo=media(license=None))]})

        self.assertFails("'license' is missing or empty")

    def test_empty_attribution_fails(self):
        self.write_photo()
        self.write_manifest({"species": [species(photo=media(attribution="   "))]})

        self.assertFails("'attribution' is missing or empty")

    def test_missing_attribution_fails(self):
        self.write_photo()
        self.write_manifest({"species": [species(photo=media(attribution=None))]})

        self.assertFails("'attribution' is missing or empty")

    def test_missing_source_url_fails(self):
        self.write_photo()
        self.write_manifest({"species": [species(photo=media(sourceURL=None))]})

        self.assertFails("'sourceURL' is missing or empty")

    def test_missing_file_field_fails(self):
        self.write_manifest({"species": [species(photo=media(file=None))]})

        self.assertFails("'file' is missing or empty")

    def test_missing_photo_fails(self):
        self.write_manifest({"species": [species(photo=None)]})

        self.assertFails("'photo' is missing")


class HashTests(LicenseGateTestCase):
    def test_sha256_mismatch_fails(self):
        self.write_photo(content=b"a different photo entirely")
        self.write_manifest({"species": [species()]})

        self.assertFails("sha256 does not match")

    def test_missing_sha256_fails_when_the_file_is_present(self):
        self.write_photo()
        self.write_manifest({"species": [species(photo=media(sha256=None))]})

        self.assertFails("'sha256' is missing or empty")

    def test_absent_file_skips_the_hash_check(self):
        self.write_manifest({"species": [species(photo=media(sha256="deadbeef"))]})

        output = self.assertPasses()
        self.assertIn("not present locally: 1", output)

    def test_absent_file_still_has_its_metadata_checked(self):
        self.write_manifest({"species": [species(photo=media(license="CC-BY-NC-4.0"))]})

        self.assertFails("amsel / photo", "CC-BY-NC-4.0")


class ManifestShapeTests(LicenseGateTestCase):
    def test_malformed_json_fails(self):
        (self.packs_dir / "basis.json").write_text("{ this is not json", encoding="utf-8")

        self.assertFails("is not valid JSON")

    def test_unknown_shape_fails(self):
        self.write_manifest({"id": "basis", "title": "Basis"})

        self.assertFails("no species found")

    def test_species_that_is_not_an_object_fails(self):
        self.write_manifest({"species": ["amsel"]})

        self.assertFails("species #1: is not an object")

    def test_species_without_id_is_named_by_position(self):
        self.write_manifest({"species": [species(id=None, photo=media(license="CC-BY-NC-4.0"))]})

        self.assertFails("species #1 / photo")

    def test_missing_packs_directory_fails(self):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            code = license_gate.main([str(self.packs_dir / "nowhere")])

        self.assertEqual(code, 1, output.getvalue())
        self.assertIn("::error::Pack directory not found", output.getvalue())


if __name__ == "__main__":
    unittest.main()
