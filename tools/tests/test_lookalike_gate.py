"""Tests for the look-alike gate.

Run from the repository root:
python3 -m unittest discover -s tools/tests -t tools -p 'test_lookalike_gate.py'
"""

from __future__ import annotations

import contextlib
import io
import json
import tempfile
import unittest
from pathlib import Path

import lookalike_gate


def bird(**overrides) -> dict:
    """A bird entry carrying a look-alike group, with fields replaced or removed.

    A field set to None is removed, which is how the tests express "missing".
    """
    entry = {"id": "amsel", "name": "Amsel", "lookalike": "thrush"}
    entry.update(overrides)
    return {key: value for key, value in entry.items() if value is not None}


class LookalikeGateTestCase(unittest.TestCase):
    """Base class providing a throwaway packs directory."""

    def setUp(self) -> None:
        self._directory = tempfile.TemporaryDirectory()
        self.addCleanup(self._directory.cleanup)
        self.packs_dir = Path(self._directory.name) / "packs"
        self.packs_dir.mkdir()

    def write_manifest(self, document, name: str = "basis.json") -> Path:
        path = self.packs_dir / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(document), encoding="utf-8")
        return path

    def run_gate(self, packs_dir: Path | None = None) -> tuple[int, str]:
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            code = lookalike_gate.main([str(packs_dir or self.packs_dir)])
        return code, output.getvalue()


class ConsistentPackTests(LookalikeGateTestCase):
    def test_consistent_pair_passes(self):
        self.write_manifest({"birds": [bird(id="amsel", lookalike="thrush")]}, "basis.json")
        self.write_manifest({"birds": [bird(id="rotkehlchen", lookalike="thrush")]}, "nordamerika.json")

        self.assertEqual(lookalike_gate.check(self.packs_dir), [])

    def test_same_id_with_the_same_group_in_two_packs_passes(self):
        # A bird may sit in more than one pack, as long as the packs agree.
        self.write_manifest({"birds": [bird(id="amsel", lookalike="thrush")]}, "basis.json")
        self.write_manifest({"birds": [bird(id="amsel", lookalike="thrush")]}, "deutschland.json")

        self.assertEqual(lookalike_gate.check(self.packs_dir), [])

    def test_manifest_in_a_pack_subdirectory_is_checked(self):
        # rglob: a pack with its own directory must not escape the gate.
        self.write_manifest({"birds": [bird(lookalike=None)]}, "deutschland/birds.json")

        problems = lookalike_gate.check(self.packs_dir)
        self.assertEqual(len(problems), 1)
        self.assertIn("deutschland/birds.json", problems[0])

    def test_every_group_in_the_vocabulary_is_accepted(self):
        for group in lookalike_gate.GROUPS:
            with self.subTest(group=group):
                self.write_manifest({"birds": [bird(lookalike=group)]})

                self.assertEqual(lookalike_gate.check(self.packs_dir), [])


class MissingGroupTests(LookalikeGateTestCase):
    def test_bird_without_a_lookalike_is_reported(self):
        self.write_manifest({"birds": [bird(lookalike=None)]}, "basis.json")

        problems = lookalike_gate.check(self.packs_dir)

        self.assertEqual(len(problems), 1)
        self.assertIn("basis.json", problems[0])
        self.assertIn("amsel", problems[0])
        self.assertIn("'lookalike' is missing or empty", problems[0])

    def test_empty_or_blank_lookalike_is_reported_as_missing(self):
        for value in ("", "   "):
            with self.subTest(lookalike=value):
                self.write_manifest({"birds": [bird(lookalike=value)]}, "basis.json")

                problems = lookalike_gate.check(self.packs_dir)

                self.assertEqual(len(problems), 1)
                self.assertIn("'lookalike' is missing or empty", problems[0])

    def test_bird_without_id_is_named_by_position(self):
        self.write_manifest({"birds": [bird(id=None, lookalike=None)]}, "basis.json")

        problems = lookalike_gate.check(self.packs_dir)

        self.assertEqual(len(problems), 1)
        self.assertIn("bird #1", problems[0])


class UnknownGroupTests(LookalikeGateTestCase):
    def test_unknown_group_is_reported_with_the_bird_and_the_pack(self):
        self.write_manifest({"birds": [bird(lookalike="hahn")]}, "basis.json")

        problems = lookalike_gate.check(self.packs_dir)

        self.assertEqual(len(problems), 1)
        self.assertIn("basis.json", problems[0])
        self.assertIn("amsel", problems[0])
        self.assertIn("'hahn' is not a known group", problems[0])

    def test_a_group_that_is_not_a_string_is_reported(self):
        self.write_manifest({"birds": [bird(lookalike=["thrush"])]}, "basis.json")

        problems = lookalike_gate.check(self.packs_dir)

        self.assertEqual(len(problems), 1)
        self.assertIn("is not a known group", problems[0])


class ConflictTests(LookalikeGateTestCase):
    def test_same_id_with_two_groups_across_packs_names_both_packs(self):
        self.write_manifest({"birds": [bird(id="amsel", lookalike="thrush")]}, "basis.json")
        self.write_manifest({"birds": [bird(id="amsel", lookalike="finch")]}, "nordamerika.json")

        problems = lookalike_gate.check(self.packs_dir)

        self.assertEqual(len(problems), 1)
        self.assertIn("amsel", problems[0])
        self.assertIn("basis.json", problems[0])
        self.assertIn("nordamerika.json", problems[0])
        self.assertIn("thrush", problems[0])
        self.assertIn("finch", problems[0])


class ManifestTests(LookalikeGateTestCase):
    def test_unreadable_manifest_is_reported(self):
        (self.packs_dir / "basis.json").write_text("{ this is not json", encoding="utf-8")

        problems = lookalike_gate.check(self.packs_dir)

        self.assertEqual(len(problems), 1)
        self.assertIn("basis.json", problems[0])
        self.assertIn("cannot be read", problems[0])

    def test_manifest_without_birds_is_left_to_the_licence_gate(self):
        # The shape is the licence gate's business; this gate only judges birds.
        self.write_manifest({"id": "basis", "title": "Basis"})

        self.assertEqual(lookalike_gate.check(self.packs_dir), [])


class MainTests(LookalikeGateTestCase):
    def test_main_passes_on_a_consistent_pack(self):
        self.write_manifest({"birds": [bird()]})

        code, output = self.run_gate()

        self.assertEqual(code, 0, output)
        self.assertNotIn("::error", output)
        self.assertIn("Look-alike gate passed", output)

    def test_main_fails_on_a_problem_and_annotates_it(self):
        self.write_manifest({"birds": [bird(lookalike=None)]}, "basis.json")

        code, output = self.run_gate()

        self.assertEqual(code, 1, output)
        self.assertIn("::error::", output)
        self.assertIn("basis.json", output)
        self.assertIn("Look-alike gate failed: 1 problem(s)", output)

    def test_main_reports_every_problem_before_it_exits(self):
        self.write_manifest({"birds": [bird(lookalike=None), bird(id="amsel-2", lookalike="hahn")]})

        code, output = self.run_gate()

        self.assertEqual(code, 1, output)
        self.assertEqual(output.count("::error::"), 2)

    def test_missing_packs_directory_fails(self):
        code, output = self.run_gate(self.packs_dir / "nowhere")

        self.assertEqual(code, 1, output)
        self.assertIn("::error::Pack directory not found", output)


class CuratedPacksTests(unittest.TestCase):
    """The real manifests, so a curation mistake fails the tests as well as
    the gate step."""

    def test_the_curated_packs_pass(self):
        self.assertEqual(lookalike_gate.check(lookalike_gate.DEFAULT_PACKS_DIR), [])


if __name__ == "__main__":
    unittest.main()
