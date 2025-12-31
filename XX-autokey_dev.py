#!/usr/bin/env python3
"""
🚀 Professional AutoKey Phrase Generator
Generates a structured library of development phrases/snippets for AutoKey.
Organizes snippets into subfolders by category (Python, JS, SQL, etc).
"""

import json
import argparse
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Any

# Define development phrases with structured categories
DEV_LIBRARY: Dict[str, Dict[str, str]] = {
    "Python": {
        "pymain": 'if __name__ == "__main__":\n    main()',
        "pyclass": "class ClassName:\n    def __init__(self, param):\n        self.param = param\n\n    def method(self):\n        pass",
        "pytry": "try:\n    # code\nexcept Exception as e:\n    logging.error(f'Error: {e}')\n    raise",
        "pylog": "import logging\nlogging.basicConfig(level=logging.INFO)\nlogger = logging.getLogger(__name__)",
        "pytest": "def test_func():\n    # Arrange\n    # Act\n    # Assert\n    assert True",
        "pydoc": '"""Module docstring."""',
        "pypath": "from pathlib import Path\nbase_dir = Path(__file__).parent",
    },
    "JavaScript": {
        "jsarrow": "const func = (p) => { return r; };",
        "jsasync": "async function name() {\n  try {\n    const r = await fetch(url);\n  } catch (e) { console.error(e); }\n}",
        "jspromise": "new Promise((res, rej) => { if(s) res(r); else rej(e); });",
        "jsmap": "array.map(i => i);",
        "jstry": "try { } catch (e) { console.error(e); }",
    },
    "SQL": {
        "sqlselect": "SELECT * FROM table WHERE condition ORDER BY id DESC;",
        "sqlinsert": "INSERT INTO table (c1, c2) VALUES (v1, v2);",
        "sqlupdate": "UPDATE table SET c1 = v1 WHERE condition;",
        "sqljoin": "SELECT * FROM t1 JOIN t2 ON t1.id = t2.f_id;",
    },
    "Docker": {
        "dockerfile": "FROM python:3.11-slim\nWORKDIR /app\nCOPY . .\nRUN pip install -r requirements.txt\nCMD [\"python\", \"app.py\"]",
        "dockercomp": "version: '3.8'\nservices:\n  app:\n    build: .\n    ports:\n      - \"8000:8000\"",
    },
    "Git": {
        "gitrebase": "git fetch origin && git rebase origin/main",
        "gitreset": "git reset --hard HEAD~1",
        "gitstash": "git stash push -m \"wip\" && git stash pop",
        "gitamend": "git commit --amend --no-edit",
    }
}

METADATA_TEMPLATE = {
    "usageCount": 0, "omitTrigger": False, "prompt": False,
    "abbreviation": {
        "abbreviations": [], "wordChars": "[\\w]", "immediate": False,
        "ignoreCase": False, "backspace": True, "triggerInside": False
    },
    "hotkey": {"hotKey": None, "modifiers": []},
    "modes": [1], "showInTrayMenu": False, "matchCase": False,
    "filter": {"regex": None, "isRecursive": False},
    "type": "phrase", "sendMode": "kb"
}

FOLDER_TEMPLATE = {
    "type": "folder", "title": "", "modes": [], "usageCount": 0,
    "showInTrayMenu": False,
    "abbreviation": {"abbreviations": [], "wordChars": "[\\w]"},
    "hotkey": {"hotKey": None, "modifiers": []},
    "filter": {"regex": None, "isRecursive": False}
}

class AutoKeyGen:
    def __init__(self, target_name: str = "DevSnippets"):
        self.data_dir = self._find_autokey_dir()
        self.root_folder = self.data_dir / target_name

    def _find_autokey_dir(self) -> Path:
        paths = [
            Path.home() / ".config" / "autokey" / "data",
            Path.home() / ".local" / "share" / "autokey" / "data"
        ]
        for p in paths:
            if p.exists(): return p
        p = paths[0]
        p.mkdir(parents=True, exist_ok=True)
        return p

    def write_json(self, path: Path, data: Dict):
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2)

    def create_folder(self, path: Path, title: str):
        path.mkdir(exist_ok=True)
        meta = FOLDER_TEMPLATE.copy()
        meta["title"] = title
        self.write_json(path / ".folder.json", meta)

    def create_phrase(self, folder: Path, abbrev: str, content: str, category: str):
        (folder / f"{abbrev}.txt").write_text(content, encoding='utf-8')
        meta = METADATA_TEMPLATE.copy()
        meta["description"] = f"{category}: {abbrev}"
        meta["abbreviation"]["abbreviations"] = [abbrev]
        self.write_json(folder / f".{abbrev}.json", meta)

    def generate(self):
        print(f"🚀 Generating AutoKey Library at: {self.root_folder}")
        self.create_folder(self.root_folder, "Development Snippets")
        
        for category, phrases in DEV_LIBRARY.items():
            cat_folder = self.root_folder / category
            self.create_folder(cat_folder, category)
            print(f"  📦 {category}")
            for abbrev, content in phrases.items():
                self.create_phrase(cat_folder, abbrev, content, category)
                print(f"    ✓ {abbrev}")

    def cleanup(self):
        if self.root_folder.exists():
            import shutil
            shutil.rmtree(self.root_folder)
            print(f"🗑 Removed: {self.root_folder}")

def main():
    parser = argparse.ArgumentParser(description="AutoKey Snippet Generator")
    parser.add_argument("--clean", action="store_true", help="Remove generated snippets")
    args = parser.parse_args()

    gen = AutoKeyGen()
    if args.clean:
        gen.cleanup()
    else:
        gen.generate()
        print(f"\n✨ Done. Please restart AutoKey to see changes.")

if __name__ == "__main__":
    main()
