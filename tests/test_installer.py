"""Integration checks run only against isolated temporary destinations."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class InstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.codex = self.base / 'codex skills'
        self.claude = self.base / 'claude config'
        self.bin = self.base / 'bin'
        self.bin.mkdir()
        # Any attempt to configure services is a failure in skills-only tests.
        for name in ('claude', 'codex'):
            mock = self.bin / name
            mock.write_text('#!/bin/sh\necho called >> "$CALL_LOG"\nexit 99\n')
            mock.chmod(0o755)
        self.env = dict(os.environ, CODEX_SKILLS_DIR=str(self.codex),
                        CLAUDE_CONFIG_DIR=str(self.claude),
                        PATH=f'{self.bin}{os.pathsep}{os.environ["PATH"]}',
                        CALL_LOG=str(self.base / 'calls'))

    def run_installer(self, *args):
        return subprocess.run(['bash', str(ROOT / 'instalar.sh'), *args],
                              env=self.env, text=True, capture_output=True)

    def test_codex_copies_all_assets_and_normalizes_entry_points(self):
        result = self.run_installer('--destino', 'codex')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse(self.claude.exists())
        self.assertFalse((self.base / 'calls').exists())
        self.assertEqual(len(list(self.codex.glob('*/SKILL.md'))), 24)
        for source in (ROOT / 'skills-claude-code').iterdir():
            if not (source / 'SKILL.md').is_file():
                continue
            target = self.codex / source.name
            text = (target / 'SKILL.md').read_text()
            self.assertIn(f'name: {source.name}\n', text)
            self.assertIn('Compatibilidade com Codex', text)
            self.assertNotIn('allowed-tools:', text.split('---', 2)[1])
            self.assertTrue(text.endswith((source / 'SKILL.md').read_text().split('---', 2)[2]))
            for asset in source.rglob('*'):
                if asset.is_file() and asset != source / 'SKILL.md':
                    self.assertEqual(asset.read_bytes(), (target / asset.relative_to(source)).read_bytes())
        marker = self.codex / 'brag' / 'SKILL.md'
        marker.write_text('customized')
        self.assertEqual(self.run_installer('--destino=codex').returncode, 0)
        self.assertEqual(marker.read_text(), 'customized')
        self.assertFalse((self.codex / 'brag' / 'brag').exists())

    def test_both_and_default_preserve_claude_files(self):
        result = self.run_installer('--destino', 'ambos', '--sem-plugins', '--sem-mcp')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(len(list((self.claude / 'skills').glob('*/SKILL.md'))), 24)
        for source in (ROOT / 'skills-claude-code').glob('*/SKILL.md'):
            self.assertEqual(source.read_bytes(), (self.claude / 'skills' / source.parent.name / 'SKILL.md').read_bytes())
        self.assertEqual(self.run_installer('--sem-plugins', '--sem-mcp').returncode, 0)
        self.assertFalse((self.base / 'calls').exists())

    def test_invalid_arguments_do_not_create_destinations(self):
        for args in [('--destino',), ('--destino=invalid',), ('--unknown',)]:
            self.assertEqual(self.run_installer(*args).returncode, 2)
        self.assertFalse(self.codex.exists())
        self.assertFalse(self.claude.exists())

    def test_codex_keeps_existing_broken_symlink(self):
        self.codex.mkdir()
        existing = self.codex / 'brag'
        existing.symlink_to(self.base / 'missing')
        result = self.run_installer('--destino=codex')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(existing.is_symlink())
        self.assertFalse(existing.exists())


if __name__ == '__main__':
    unittest.main()
