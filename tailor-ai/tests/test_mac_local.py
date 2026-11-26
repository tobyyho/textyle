"""Portability tests that do not require a downloaded model or a GPU."""
from __future__ import annotations

import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import types
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('tailor_mac_launcher', ROOT / 'scripts/macos/mac_local.py')
launcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launcher)


class FakeModelFactory:
    calls = []
    @classmethod
    def from_pretrained(cls, model, **kwargs):
        cls.calls.append((model, kwargs))
        return cls()
    def to(self, device):
        return self
    def eval(self):
        return self


class MacLocalTests(unittest.TestCase):
    def test_local_paths_handle_spaces_and_key_is_stable(self):
        with tempfile.TemporaryDirectory(prefix='tailor mac paths ') as directory, patch.dict(os.environ, {'TAILOR_MAC_DATA_ROOT': directory}):
            first = launcher.configure()
            key = first['key'].read_text()
            second = launcher.configure()
            self.assertEqual(second['key'].read_text(), key)
            self.assertGreaterEqual(len(key.strip()), 32)
            self.assertEqual(os.environ['TAILOR_DEVICE'], 'cpu')
            self.assertEqual(Path(os.environ['TAILOR_HF_CACHE']), first['cache'])
            self.assertEqual(Path(os.environ['TAILOR_RUNTIME_DIR']), launcher.ARTIFACTS)
            self.assertEqual(first['key'].stat().st_mode & 0o777, 0o600)

    def test_classifier_and_template_hashes_match(self):
        launcher.verify()

    def test_changed_classifier_is_rejected_before_inference(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root/'artifact_manifest.json').write_text((launcher.ARTIFACTS/'artifact_manifest.json').read_text())
            (root/'best_model_state.pt').write_bytes(b'changed checkpoint')
            with patch.object(launcher, 'ARTIFACTS', root), self.assertRaises(RuntimeError):
                launcher.verify()

    def test_sam_provider_uses_configured_cache_and_stays_offline(self):
        fake_torch = types.ModuleType('torch')
        fake_torch.device = lambda value: types.SimpleNamespace(type=str(value))
        fake_transformers = types.ModuleType('transformers')
        fake_transformers.Sam2Model = FakeModelFactory
        fake_transformers.Sam2Processor = FakeModelFactory
        fake_digitization = types.ModuleType('tailor_ai.digitization')
        fake_digitization.__path__ = [str(ROOT/'src/tailor_ai/digitization')]
        source = ROOT/'src/tailor_ai/providers/segmentation/sam2_tiny.py'
        provider_spec = importlib.util.spec_from_file_location('mac_sam_provider_test', source)
        provider = importlib.util.module_from_spec(provider_spec)
        FakeModelFactory.calls = []
        with tempfile.TemporaryDirectory(prefix='sam cache ') as directory, patch.dict(os.environ, {'TAILOR_HF_CACHE': directory}), patch.dict(sys.modules, {'torch': fake_torch, 'transformers': fake_transformers, 'tailor_ai.digitization': fake_digitization}):
            provider_spec.loader.exec_module(provider)
            provider.Sam2TinySegmenter('cpu')
            self.assertEqual(len(FakeModelFactory.calls), 2)
            for model, arguments in FakeModelFactory.calls:
                self.assertEqual(model, 'facebook/sam2.1-hiera-tiny')
                self.assertEqual(arguments['cache_dir'], Path(directory))
                self.assertTrue(arguments['local_files_only'])
                self.assertEqual(arguments['revision'], launcher.model_settings()[1])

if __name__ == '__main__':
    unittest.main()
