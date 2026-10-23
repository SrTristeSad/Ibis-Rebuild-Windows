"""Meaningful negative checks for the source publication boundary."""
import pathlib
import sys
import unittest
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'tools'))
from prepare_repository import review_file

class PublicationBoundary(unittest.TestCase):
    def test_independent_source_allowed(self):
        self.assertEqual(review_file('native/core.cpp', b'extern "C" int version() { return 1; }'), [])

    def test_artifacts_and_user_projects_rejected(self):
        for name in ['engine.so', 'classes.dex', 'base.apk', 'source.tar.gz',
                     'app.exe', 'core.dll', 'drawing.rbd', 'capture.png', 'backup.zip']:
            with self.subTest(name=name):
                self.assertTrue(review_file(name, b'placeholder'))

    def test_binary_disguised_as_source_rejected(self):
        self.assertIn('binary-content', review_file('native/data.cpp', b'MZpayload'))
        self.assertIn('binary-content', review_file('docs/data.md', b'text\0hidden'))

    def test_credential_shaped_text_rejected(self):
        self.assertIn('github-token', review_file('docs/example.md', ('gh' + 'p_' + 'a' * 36).encode()))
        self.assertIn('aws-access-key', review_file('docs/example.md', ('AK' + 'IA' + 'A' * 16).encode()))

    def test_machine_profile_path_rejected(self):
        path = ('C:' + '\\' + 'Users' + '\\' + 'ExamplePerson' + '\\file').encode()
        self.assertIn('personal-profile-path', review_file('docs/log.md', path))

    def test_raw_decompiler_result_rejected(self):
        raw = ('{"raw_' + 'result": {}}').encode()
        self.assertIn('decompiler-record', review_file('docs/raw.json', raw))

    def test_local_only_directories_rejected(self):
        for name in ['build/a.txt', 'evidence/record.json', 'tools/archive/old.py']:
            self.assertTrue(review_file(name, b'text'))

    def test_traversal_rejected(self):
        self.assertTrue(review_file('../outside.txt', b'text'))

if __name__ == '__main__':
    unittest.main(verbosity=2)
