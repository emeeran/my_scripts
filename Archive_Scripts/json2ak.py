
#!/usr/bin/env python3
"""
import_to_autokey.py  (rev B)

Purpose
-------
Import snippets from JSON into AutoKey phrases and **convert triggers like "chef/"
into ".chef"** so typing `.chef` expands the associated text.

Key Changes vs previous version
-------------------------------
- New trigger normalization: any provided trigger/abbrev ending with "/" will be
  converted to dot-trigger form: e.g., "chef/" -> ".chef".
- For datasets like your "AI Prompts.json" (entries have tags under key "1" and text
  under key "4"), the importer will **derive the trigger** from the first tag:
  ["chef/"] -> ".chef".
- Abbreviations are set with **immediate=True**, so `.chef` expands as soon as it’s typed.
  (You can override with --no-immediate.)

Supported Input Shapes
----------------------
1) Flat dict (abbrev -> text)
2) List of objects (name/abbrev/text/etc.)
3) Grouped dict (group -> flat/list)
4) "AI Prompts.json" style (objects with "1": [tags], "4": body, "0": id)

Usage
-----
Interactive:
  python3 import_to_autokey.py

Non-interactive:
  python3 import_to_autokey.py --source snippets.json --group "Imported"
  python3 import_to_autokey.py --source "AI Prompts.json" --group "Prompts" --send-mode cb

Options:
  --base PATH          Base AutoKey data folder (default: ~/.config/autokey/data)
  --overwrite          Overwrite files if names collide
  --no-immediate       Disable immediate expansion (default is immediate ON)
  --send-mode {kb,cb}  kb=type keys, cb=paste from clipboard (faster for long text)

After import: restart AutoKey so it reloads the folders.
"""

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any, Dict, Iterable, List, Tuple, Optional

DEFAULT_BASE = Path.home() / ".config" / "autokey" / "data"

def slugify(value: str, max_len: int = 60) -> str:
    value = (value or "").strip()
    value = re.sub(r"[^\w\s\-\.]", "-", value)
    value = re.sub(r"\s+", "-", value)
    value = re.sub(r"-{2,}", "-", value).strip("-._")
    return value[:max_len] or "untitled"

def ensure_group_folder(base: Path, group_name: str) -> Path:
    group_dir = base / slugify(group_name)
    group_dir.mkdir(parents=True, exist_ok=True)
    return group_dir

def load_json(path: Path) -> Any:
    text = path.read_text(encoding="utf-8", errors="ignore")
    text = text.replace("\ufeff", "").replace("\x00", "")
    return json.loads(text)

# ---------- Trigger normalization ----------

def normalize_trigger(raw: Optional[str]) -> str:
    """
    Convert "chef/" -> ".chef"; leave ".xyz" intact; strip whitespace.
    If trigger is empty/None, return "".
    """
    if not raw:
        return ""
    t = str(raw).strip()
    # remove surrounding quotes/spaces
    t = t.strip('"\''" ”‘’“”")
    # if ends with /, drop it
    if t.endswith("/"):
        t = t[:-1]
    # ensure leading dot
    if not t.startswith("."):
        t = "." + t
    return t

def derive_trigger_from_tags(tags: Any) -> str:
    """
    Use first non-empty tag as trigger; supports shapes like ["chef/"] => ".chef"
    """
    if isinstance(tags, list):
        for tag in tags:
            if isinstance(tag, str) and tag.strip():
                return normalize_trigger(tag)
    elif isinstance(tags, str) and tags.strip():
        return normalize_trigger(tags)
    return ""

# ---------- Input normalization to a common item dict ----------

def make_item(name: Optional[str], abbrev: str, text: str, extra: Dict[str, Any] = None,
              immediate_default: bool = True) -> Dict[str, Any]:
    d = {
        "name": name or (abbrev.lstrip(".") if abbrev else "snippet"),
        "abbrev": abbrev,
        "text": text,
        "description": "",
        "hotkey": [],
        "sendMode": None,                # None => use CLI default
        "immediate": immediate_default,  # default ON now
        "ignoreCase": False,
        "triggerInside": False,
        "wordChars": r"[\w]",            # keep dot as non-word so boundary after 'f' expands
    }
    if extra:
        d.update({k: v for k, v in extra.items() if v is not None})
    return d

def normalize_items(data: Any, immediate_default: bool) -> Iterable[Tuple[str, Dict[str, Any]]]:
    """
    Yield (group_name, item_dict). Accepts multiple JSON shapes including
    the AI Prompts style where body is "4" and tags array in "1".
    """
    # Case 1: list of objects
    if isinstance(data, list):
        for obj in data:
            if not isinstance(obj, dict):
                continue
            # Prefer explicit abbrev; else derive from 'tags' key variants
            raw_abbrev = obj.get("abbrev") or obj.get("trigger") or obj.get("abbr") or ""
            if raw_abbrev:
                abbrev = normalize_trigger(raw_abbrev)
            else:
                abbrev = derive_trigger_from_tags(obj.get("tags") or obj.get("1"))
            text = (obj.get("text") or obj.get("phrase") or obj.get("content") or obj.get("4") or "")
            if not text:
                continue
            name = obj.get("name") or (abbrev.lstrip(".") if abbrev else (text[:40] if isinstance(text, str) else "snippet"))
            group = obj.get("group") or "Imported"
            yield (group, make_item(name, abbrev, text, obj, immediate_default))
        return

    # Case 2: dict – either flat (abbr->text), grouped, or AI Prompts style tree
    if isinstance(data, dict):
        # Heuristic: AI Prompts style top-level has key "4" as a list of category objects
        if "4" in data and isinstance(data["4"], list):
            # Dive recursively to find entries with "4" body and "1" tags
            yield from _iter_ai_prompts(data, immediate_default)
            return

        # Grouped dict vs flat dict
        is_grouped = any(isinstance(v, (dict, list)) for v in data.values())
        if not is_grouped:
            for abbr, text in data.items():
                if isinstance(text, (str, int, float)):
                    abbrev = normalize_trigger(str(abbr))
                    yield ("Imported", make_item(None, abbrev, str(text), None, immediate_default))
                elif isinstance(text, dict):
                    raw_abbrev = text.get("abbrev") or str(abbr)
                    abbrev = normalize_trigger(raw_abbrev)
                    body = text.get("text") or text.get("phrase") or text.get("content") or text.get("4") or ""
                    if body:
                        yield ("Imported", make_item(text.get("name"), abbrev, body, text, immediate_default))
            return

        # Grouped
        for group, container in data.items():
            if isinstance(container, list):
                for obj in container:
                    if not isinstance(obj, dict):
                        continue
                    raw_abbrev = obj.get("abbrev") or obj.get("trigger") or obj.get("abbr") or ""
                    if raw_abbrev:
                        abbrev = normalize_trigger(raw_abbrev)
                    else:
                        abbrev = derive_trigger_from_tags(obj.get("tags") or obj.get("1"))
                    text = (obj.get("text") or obj.get("phrase") or obj.get("content") or obj.get("4") or "")
                    if not text:
                        continue
                    name = obj.get("name") or (abbrev.lstrip(".") if abbrev else (text[:40] if isinstance(text, str) else "snippet"))
                    yield (group, make_item(name, abbrev, text, obj, immediate_default))
            elif isinstance(container, dict):
                # Could be flat or nested objects; process key/value
                for k, v in container.items():
                    if isinstance(v, (str, int, float)):
                        abbrev = normalize_trigger(str(k))
                        yield (group, make_item(None, abbrev, str(v), None, immediate_default))
                    elif isinstance(v, dict):
                        raw_abbrev = v.get("abbrev") or v.get("trigger") or v.get("abbr") or str(k)
                        abbrev = normalize_trigger(raw_abbrev)
                        text = v.get("text") or v.get("phrase") or v.get("content") or v.get("4") or ""
                        if text:
                            yield (group, make_item(v.get("name"), abbrev, text, v, immediate_default))
        return

    raise SystemExit("Unrecognized JSON shape.")

def _iter_ai_prompts(node: Any, immediate_default: bool, lineage: Optional[List[str]] = None) -> Iterable[Tuple[str, Dict[str, Any]]]:
    """
    Walk the AI Prompts-style tree. Yields items where dict has body in key "4".
    """
    if lineage is None:
        lineage = []
    if isinstance(node, dict):
        # Leaf entry: has text in key "4" and (optionally) tags in key "1"
        if isinstance(node.get("4"), str):
            body = node.get("4") or ""
            tags = node.get("1") or []
            abbrev = derive_trigger_from_tags(tags)
            name = (abbrev.lstrip(".") if abbrev else (body[:40] if body else "snippet"))
            group = lineage[0] if lineage else "Imported"
            yield (group, make_item(name, abbrev, body, node, immediate_default))
            return
        # Track group names from key "2"
        label = node.get("2")
        if isinstance(label, str) and label.strip():
            lineage.append(label.strip())
        for v in node.values():
            yield from _iter_ai_prompts(v, immediate_default, lineage)
        if isinstance(label, str) and label.strip():
            lineage.pop()
    elif isinstance(node, list):
        for item in node:
            yield from _iter_ai_prompts(item, immediate_default, lineage)

# ---------- Writing AutoKey phrase files ----------

def write_phrase_files(group_dir: Path, item: Dict[str, Any], default_send_mode: str, overwrite: bool) -> Path:
    base_name = slugify(item["name"] or item["abbrev"] or "snippet")
    phrase_txt = group_dir / f"{base_name}.txt"
    meta_json = group_dir / f".{base_name}.json"

    if not overwrite:
        i = 2
        while phrase_txt.exists() or meta_json.exists():
            phrase_txt = group_dir / f"{base_name} ({i}).txt"
            meta_json = group_dir / f".{base_name} ({i}).json"
            i += 1

    # Body
    phrase_txt.write_text(item["text"] or "", encoding="utf-8")

    # Build metadata
    abbrev = item.get("abbrev") or ""
    word_chars = item.get("wordChars") or r"[\w]"
    immediate = bool(item.get("immediate", True))
    ignore_case = bool(item.get("ignoreCase", False))
    trigger_inside = bool(item.get("triggerInside", False))
    description = item.get("description") or ""
    hotkey = item.get("hotkey") or []

    meta = {
        "type": "phrase",
        "name": item.get("name") or base_name,
        "abbreviation": {
            "wordChars": word_chars,
            "abbrev": abbrev,
            "immediate": immediate,
            "ignoreCase": ignore_case,
            "triggerInside": trigger_inside
        },
        "hotkey": {"modifiers": hotkey[:-1], "hotKey": hotkey[-1]} if hotkey else {},
        "modes": ["DEFAULT"],
        "usageCount": 0,
        "prompt": False,
        "showInTrayMenu": False,
        "omitTrigger": False,
        "matchCase": False,
        "description": description,
        "filter": {"regex": None, "isRecursive": False},
        "sendMode": item.get("sendMode") or default_send_mode
    }

    meta_json.write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
    return phrase_txt

def main():
    ap = argparse.ArgumentParser(description="Import snippets JSON into AutoKey phrases (converts 'chef/' -> '.chef').")
    ap.add_argument("--source", type=Path, help="Path to input JSON with snippets")
    ap.add_argument("--group", type=str, help="AutoKey group/folder name (created if missing)", default="Imported")
    ap.add_argument("--base", type=Path, help="Base AutoKey data folder", default=DEFAULT_BASE)
    ap.add_argument("--send-mode", choices=["kb","cb"], default="kb",
                    help="Default paste method: 'kb' types keys; 'cb' pastes from clipboard")
    ap.add_argument("--overwrite", action="store_true", help="Overwrite existing phrase files if names collide")
    ap.add_argument("--no-immediate", action="store_true", help="Disable immediate expansion (default ON)")
    args = ap.parse_args()

    # Interactive fallbacks
    if not args.source:
        p = input("Path to source JSON: ").strip().strip('"').strip("'")
        args.source = Path(p)
    if not args.group:
        args.group = input("Group (folder) name [Imported]: ").strip() or "Imported"

    if not args.source.exists():
        sys.exit(f"[ERROR] Source not found: {args.source}")

    data = load_json(args.source)

    # Create base/group
    base = args.base.expanduser()
    group_dir = ensure_group_folder(base, args.group)

    immediate_default = not args.no_immediate
    count = 0
    for group, item in normalize_items(data, immediate_default=immediate_default):
        # Ensure trigger converted if provided as raw abbrev in item
        if item.get("abbrev"):
            item["abbrev"] = normalize_trigger(item["abbrev"])
        # If JSON had no trigger, skip item (AutoKey requires an abbrev to expand)
        if not item.get("abbrev"):
            # Create a name-only phrase without abbreviation (can be used from menu)
            # To force expansion-only phrases, skip uncomment next line
            # continue
            pass
        target_dir = group_dir if group == args.group else ensure_group_folder(base, group)
        write_phrase_files(target_dir, item, default_send_mode=args.send_mode, overwrite=args.overwrite)
        count += 1

    print(f"[DONE] Imported {count} phrase(s).")
    print(f"[INFO] Location: {base}")
    print("[NEXT] Restart AutoKey so it reloads the folders.")

if __name__ == "__main__":
    main()
