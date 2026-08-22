#!/usr/bin/env python3

import json
import pathlib
import re
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]


class ManifestTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads((ROOT / "plugin.json").read_text(encoding="utf-8"))

    def test_manifest_contract(self):
        required = {
            "id", "name", "description", "version", "author", "type",
            "capabilities", "components", "settings", "startupCheck",
            "requires_dms", "dependencies", "permissions",
        }
        self.assertFalse(required - self.manifest.keys())
        self.assertRegex(self.manifest["id"], r"^[a-z][A-Za-z0-9]*$")
        self.assertRegex(self.manifest["version"], r"^\d+\.\d+\.\d+$")
        self.assertEqual(self.manifest["type"], "composite")
        self.assertEqual(self.manifest["requires_dms"], ">=1.5.1")
        self.assertEqual(self.manifest["dependencies"], ["cava"])

    def test_manifest_component_paths_exist(self):
        component_paths = list(self.manifest["components"].values())
        component_paths.extend((self.manifest["settings"], self.manifest["startupCheck"]))
        for value in component_paths:
            self.assertRegex(value, r"^\./.+\.qml$")
            self.assertTrue((ROOT / value[2:]).is_file(), value)

    def test_version_is_documented(self):
        changelog = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
        self.assertIn(f"## {self.manifest['version']} ", changelog)


class RegistryMetadataTests(unittest.TestCase):
    def test_prepared_registry_entry_matches_manifest(self):
        manifest = json.loads((ROOT / "plugin.json").read_text(encoding="utf-8"))
        registry = json.loads(
            (ROOT / "registry/iquantecho-enderpulse.json").read_text(encoding="utf-8")
        )
        required = {
            "id", "name", "capabilities", "category", "repo", "author",
            "description", "dependencies", "compositors", "distro", "screenshot",
        }
        self.assertFalse(required - registry.keys())
        for key in ("id", "name", "capabilities", "author", "description",
                    "dependencies", "requires_dms"):
            self.assertEqual(registry[key], manifest[key], key)
        self.assertEqual(registry["compositors"], ["any"])
        self.assertEqual(registry["distro"], ["any"])
        self.assertTrue(registry["screenshot"].endswith("/docs/enderpulse-preview.png"))
        self.assertTrue((ROOT / "docs/enderpulse-preview.png").is_file())


class RepositoryHygieneTests(unittest.TestCase):
    def test_text_files_contain_no_local_paths_or_likely_credentials(self):
        for path in ROOT.rglob("*"):
            if (not path.is_file() or ".git" in path.parts
                    or "__pycache__" in path.parts or path.suffix == ".pyc"):
                continue
            if path.suffix.lower() in {".png", ".jpg", ".jpeg", ".webp"}:
                continue
            text = path.read_text(encoding="utf-8")
            self.assertNotIn("/home/" + "simon", text, path)
            self.assertNotIn("gho" + "_", text, path)


if __name__ == "__main__":
    unittest.main()
