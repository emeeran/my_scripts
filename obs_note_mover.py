import re
import shutil
import concurrent.futures
import urllib.parse
import yaml
from pathlib import Path
from dataclasses import dataclass
from typing import List, Set, Tuple, Optional, Dict

@dataclass
class NoteMetadata:
    path: Path
    matched_tags: List[str]
    attachments: List[Path]
    size: int

# Pre-compile regex patterns for performance
WIKI_LINK_RE = re.compile(r'!?\[\[([^\]|#]+)(?:\|[^\]]+)?(?:#[^\]]+)?\]\]')
# Improved MD_LINK_RE to handle optional titles: [text](link "title")
MD_LINK_RE = re.compile(r'!?\[[^\]]*\]\(([^" \)]+)(?:\s+"[^"]*")?\)')
TAG_RE = re.compile(r'(?:^|\s)#([\w-]+)')
FRONTMATTER_RE = re.compile(r'^---\s*\n(.*?)\n---\s*\n', re.DOTALL)

def print_header(title: str):
    """Print a section header."""
    print(f"\n{'=' * 50}")
    print(f"  {title}")
    print('=' * 50)


def format_size(bytes_size: int) -> str:
    """Format bytes to human readable size."""
    for unit in ['B', 'KB', 'MB', 'GB']:
        if bytes_size < 1024:
            return f"{bytes_size:.1f} {unit}"
        bytes_size /= 1024
    return f"{bytes_size:.1f} TB"


def parse_tags(input_str: str) -> Set[str]:
    """Parse tag input from user."""
    tags = re.findall(r'#?([\w-]+)', input_str)
    return set(tags)


def resolve_attachment(link: str, note_dir: Path, vault_root: Path, vault_index: Dict[str, List[Path]]) -> Optional[Path]:
    """Extremely advanced resolution for Obsidian attachments."""
    # 1. Basic cleaning
    link = urllib.parse.unquote(link).strip()
    link = link.split('#')[0].split('?')[0]
    if not link:
        return None

    # 2. Strategy 1: Relative to note (Exact)
    path_rel = (note_dir / link).resolve()
    if path_rel.is_file():
        return path_rel

    # 3. Strategy 2: Relative to vault root (Exact)
    path_vault = (vault_root / link).resolve()
    if path_vault.is_file():
        return path_vault

    # 4. Strategy 3: Case-insensitive Relative/Vault root
    # (Checking physical existence is usually case-insensitive on Mac/Win but not Linux)
    # We rely on our index for this logic below if strategies 1 & 2 fail.

    # 5. Strategy 4: Shortest path / Name-only lookup (Obsidian Default)
    filename = Path(link).name
    lower_name = filename.lower()
    
    if lower_name in vault_index:
        candidates = vault_index[lower_name]
        
        # If we have multiple files with the same name, find the "closest" one
        # to the current note's directory by comparing common path parts.
        if len(candidates) > 1:
            def proximity(p: Path):
                # Count matching parent parts
                count = 0
                for a, b in zip(p.parts, note_dir.parts):
                    if a == b: count += 1
                    else: break
                return count
            
            return max(candidates, key=proximity)
        
        return candidates[0]

    return None


def extract_frontmatter_links(text: str) -> List[str]:
    """Extract potential file links from YAML frontmatter."""
    match = FRONTMATTER_RE.match(text)
    if not match:
        return []
    
    links = []
    try:
        data = yaml.safe_load(match.group(1))
        if not isinstance(data, dict):
            return []
            
        # Common fields for images/files in Obsidian properties
        target_keys = {'image', 'cover', 'banner', 'file', 'attachment', 'thumbnail'}
        for key, value in data.items():
            if any(tk in key.lower() for tk in target_keys):
                if isinstance(value, str):
                    # Clean wikilink syntax if present in frontmatter
                    clean_val = value.strip('[]!')
                    links.append(clean_val)
                elif isinstance(value, list):
                    for item in value:
                        if isinstance(item, str):
                            links.append(item.strip('[]!'))
    except Exception:
        pass
    return links


def find_attachments(text: str, note_dir: Path, vault_root: Path, vault_index: Dict[str, List[Path]]) -> List[Path]:
    """Find all attachment files referenced in the note using advanced resolution."""
    attachments = []

    # 1. Wiki links & Markdown links from body
    links = WIKI_LINK_RE.findall(text) + MD_LINK_RE.findall(text)
    
    # 2. Links from YAML Frontmatter
    links += extract_frontmatter_links(text)
    
    for link in links:
        if link.startswith(("http://", "https://", "//", "mailto:")):
            continue
        
        resolved = resolve_attachment(link, note_dir, vault_root, vault_index)
        # Avoid moving .md files (links) as attachments, but allow .canvas or other types
        if resolved and resolved.suffix.lower() != ".md":
            attachments.append(resolved)

    return list(set(attachments))


def process_note(note_path: Path, target_tags: Set[str], vault_root: Path, vault_index: Dict[str, List[Path]]) -> Optional[NoteMetadata]:
    """Process a single note to extract metadata if it matches tags."""
    try:
        text = note_path.read_text(encoding="utf-8", errors="replace")
        
        # Find matches using compiled regex for accuracy
        note_tags = set(TAG_RE.findall(text))
        
        # Also check tags in frontmatter if they exist
        fm_match = FRONTMATTER_RE.match(text)
        if fm_match:
            try:
                data = yaml.safe_load(fm_match.group(1))
                if isinstance(data, dict):
                    fm_tags = data.get('tags', [])
                    if isinstance(fm_tags, str):
                        note_tags.add(fm_tags.strip('#'))
                    elif isinstance(fm_tags, list):
                        for t in fm_tags:
                            if isinstance(t, str):
                                note_tags.add(t.strip('#'))
            except Exception:
                pass
        
        matched = list(target_tags.intersection(note_tags))
        
        if not matched:
            return None
            
        attachments = find_attachments(text, note_path.parent, vault_root, vault_index)
        return NoteMetadata(
            path=note_path,
            matched_tags=matched,
            attachments=attachments,
            size=note_path.stat().st_size
        )
    except Exception:
        return None


def build_vault_index(source_dir: Path, excluded: Set[str]) -> Dict[str, List[Path]]:
    """Index all files in the vault with support for duplicate names and case-insensitivity."""
    index = {}
    print(f"  📂 Building case-insensitive index: {source_dir.name}...")
    
    count = 0
    for p in source_dir.rglob("*"):
        if p.is_file() and not any(excl in p.parts for excl in excluded):
            lower_name = p.name.lower()
            if lower_name not in index:
                index[lower_name] = []
            index[lower_name].append(p)
            count += 1
    
    print(f"  ✓ Indexed {count} files")
    return index


def scan_notes_parallel(source_dir: Path, tags: Set[str], excluded_dirs: List[str]) -> List[NoteMetadata]:
    """Scan for notes in parallel for better performance."""
    excluded = set(excluded_dirs)
    vault_index = build_vault_index(source_dir, excluded)
    
    # Get all markdown files
    all_files = [
        p for p in source_dir.rglob("*.md") 
        if not any(excl in p.parts for excl in excluded)
    ]
    
    print(f"  🔍 Scanning {len(all_files)} notes for tags...")
    notes = []
    
    with concurrent.futures.ThreadPoolExecutor() as executor:
        futures = [executor.submit(process_note, p, tags, source_dir, vault_index) for p in all_files]
        for future in concurrent.futures.as_completed(futures):
            result = future.result()
            if result:
                notes.append(result)
                
    return sorted(notes, key=lambda x: x.path)


def get_path_input(prompt: str, default: Path | None = None, must_exist: bool = True) -> Path:
    """Get path input from user with validation."""
    while True:
        default_str = f" [{default}]: " if default else ": "
        user_input = input(f"{prompt}{default_str}").strip()

        path = Path(user_input).expanduser() if user_input else default

        if not path:
            print("  ⚠ Please enter a path")
            continue

        if must_exist and not path.exists():
            print(f"  ⚠ Path does not exist: {path}")
            continue

        if path.exists() and not path.is_dir():
            print(f"  ⚠ Not a directory: {path}")
            continue

        return path


def get_tags_input() -> Set[str]:
    """Get and parse tags from user input."""
    print("\n  Enter tags separated by spaces")
    print("  Example: #work #project or just work project")

    while True:
        user_input = input("\n  Tags: ").strip()
        if not user_input:
            print("  ⚠ Please enter at least one tag")
            continue

        tags = parse_tags(user_input)
        print(f"  ✓ Parsed: {', '.join(f'#{t}' for t in tags)}")
        return tags


def confirm_action(message: str) -> bool:
    """Ask user for yes/no confirmation."""
    response = input(f"\n{message} [y/N]: ").strip().lower()
    return response in ('y', 'yes')


def main():
    """Interactive main loop."""
    print("\n" + "=" * 50)
    print("  Obsidian Note Mover (Ultra Advanced)")
    print("=" * 50)

    # STEP 1: SOURCE
    print_header("Step 1: Source Directory")
    default_source = Path.home() / "Sync/obs-vault-minimal"
    source_dir = get_path_input("  Source vault", default_source, must_exist=True)

    # STEP 2: DESTINATION
    print_header("Step 2: Destination Directory")
    default_dest = Path.home() / "Sync/obs-vault-minimal/00-Inbox"
    dest_dir = get_path_input("  Destination", default_dest, must_exist=False)

    if not dest_dir.exists():
        if confirm_action(f"  Create directory: {dest_dir}?"):
            dest_dir.mkdir(parents=True, exist_ok=True)
            print(f"  ✓ Created: {dest_dir}")
        else:
            print("  Cancelled")
            return

    # STEP 3: TAGS
    print_header("Step 3: Tags to Move")
    tags = get_tags_input()

    # STEP 4: EXCLUDES
    print_header("Step 4: Exclusions")
    exclude_input = input("  Exclude (comma-sep) [.obsidian, .git, .trash]: ").strip()
    excluded_dirs = [d.strip() for d in exclude_input.split(",")] if exclude_input else [".obsidian", ".git", ".trash"]

    # STEP 5: SCAN
    print_header("Step 5: Scanning & Preview")
    notes = scan_notes_parallel(source_dir, tags, excluded_dirs)

    if not notes:
        print(f"  No notes found with tags: {', '.join(f'#{t}' for t in tags)}")
        return

    # Summary calculations
    total_size = sum(n.size for n in notes)
    total_att_count = sum(len(n.attachments) for n in notes)
    
    # Preview
    preview_limit = 10
    for i, note in enumerate(notes[:preview_limit], 1):
        rel_path = note.path.relative_to(source_dir)
        print(f"    {i}. {rel_path} ({format_size(note.size)})")
        print(f"       Tags: {', '.join(f'#{t}' for t in note.matched_tags)} | Atts: {len(note.attachments)}")

    if len(notes) > preview_limit:
        print(f"    ... and {len(notes) - preview_limit} more")

    print(f"\n  Final Plan:")
    print(f"    Notes: {len(notes)}")
    print(f"    Attachments: {total_att_count}")
    print(f"    Total Size: {format_size(total_size)}")

    if not confirm_action("  Proceed with move?"):
        print("  Cancelled")
        return

    # STEP 6: MOVE
    print_header("Step 6: Executing Move")
    moved_notes = 0
    moved_atts = 0
    errors = 0

    # Ensure dest_dir exists (re-check in case it was deleted)
    dest_dir.mkdir(parents=True, exist_ok=True)

    for i, note in enumerate(notes, 1):
        try:
            # Move attachments (avoid duplicate moves of the same file from multiple notes)
            for att in note.attachments:
                if not att.exists(): continue # Might have been moved by previous note
                
                dest_att = dest_dir / att.name
                if not dest_att.exists():
                    shutil.move(att, dest_att)
                    moved_atts += 1
                
            # Move note
            dest_note = dest_dir / note.path.name
            # If name collision at destination, append index
            if dest_note.exists():
                dest_note = dest_dir / f"{note.path.stem}_{i}{note.path.suffix}"
            
            shutil.move(note.path, dest_note)
            moved_notes += 1
            
            print(f"  [{i}/{len(notes)}] Moved: {note.path.name}", end="\r")
        except Exception as e:
            errors += 1
            print(f"\n  ✗ Error moving {note.path.name}: {e}")

    print(f"\n\n  ✅ Done!")
    print(f"  Notes moved: {moved_notes}")
    print(f"  Attachments moved: {moved_atts}")
    if errors:
        print(f"  Errors encountered: {errors}")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n  Interrupted by user")
    except Exception as e:
        print(f"\n\n  Unexpected error: {e}")
        import traceback
        traceback.print_exc()
