import unittest
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))

import validate_repo as repo  # noqa: E402


class RepositoryChecks(unittest.TestCase):
    def test_reaction_files_parse(self):
        _loaded, errors = repo.load_reactions()
        self.assertEqual(errors, [])

    def test_live_trading_is_off_by_default(self):
        self.assertEqual(repo.live_trading_errors(), [])
        self.assertEqual(repo.config_errors(), [])

    def test_env_example_is_names_only(self):
        self.assertEqual(repo.env_example_errors(), [])

    def test_gitignore_covers_binaries_and_secrets(self):
        self.assertEqual(repo.gitignore_errors(), [])

    def test_git_index_has_no_binaries_or_env(self):
        self.assertEqual(repo.index_errors(), [])

    def test_readme_has_experimental_disclaimer(self):
        readme = (ROOT / "README.md").read_text(encoding="utf-8").lower()
        self.assertIn("not financial advice", readme)
        self.assertIn("experimental", readme)
        self.assertIn("shaythegay13", readme)


if __name__ == "__main__":
    unittest.main()
