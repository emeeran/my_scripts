#!/usr/bin/env python3
"""Simple Obsidian Note Mover - Standalone script.

Moves notes with a specific tag from source to destination,
including all linked attachments.

Usage:
    python move_notes_simple.py
"""

import re
import shutil
from pathlib import Path


# ==================== CONFIGURATION ====================
# Edit these values directly or use the interactive prompts

SOURCE_DIR = Path.home() / "Sync/obsidian-vault"
DEST_DIR = Path.home() / "Sync/obs-vault-minimal/00-Inbox"
TRIGGER_TAG = "#ready"
EXCLUDED_DIRS = [".obsidian", ".git", ".trash", "templates", "copilot"]

# ======================================================


def find_attachments(text: str, note_dir: Path) -> list[Path]:
    """Find all attachment files referenced in the note."""

    # Wiki links: [[file]] or ![[file]]
        # Compile regexes once for efficiency
        WIKI_LINK_RE = re.compile(r'!?\[\[([^\]]+)\]\]')
        MD_IMG_RE = re.compile(r'!\[[^\]]*\]\(([^)]+)\)')
        REG_LINK_RE = re.compile(r'(?<!!)[^\[]*\[[^\]]*\]\(([^)]+)\)')

        attachments = set()

        # Wiki links: [[file]] or ![[file]]
        for match in WIKI_LINK_RE.finditer(text):
            link = match.group(1).split("|")[0].split("#")[0].strip()
            if link:
                attachments.add((note_dir / link).resolve())

    # Markdown images: ![alt](file)
        for match in MD_IMG_RE.finditer(text):
            link = match.group(1).strip()
            if link:
                attachments.add((note_dir / link).resolve())

    # Regular links: [text](file)
        for match in REG_LINK_RE.finditer(text):
            link = match.group(1).strip()
            if link and not link.startswith(("http://", "https://", "//")):
                attachments.add((note_dir / link).resolve())

    # Filter to existing files only
    return [a for a in attachments if a.is_file()]


def scan_notes(source_dir: Path, trigger_tag: str, excluded_dirs: list[str]) -> list[tuple[Path, str]]:
    """Scan for notes containing the trigger tag."""
    notes = []
    excluded = set(excluded_dirs)

    for note_path in source_dir.rglob("*.md"):
        # Skip excluded directories
        if any(excl in note_path.parts for excl in excluded):
            continue

        try:
            text = note_path.read_text(encoding="utf-8", errors="replace")
        except Exception:
            continue

        if trigger_tag in text:
            notes.append((note_path, text))

    return notes


def format_size(bytes_size: int) -> str:
    """Format bytes to human readable size."""
    for unit in ['B', 'KB', 'MB', 'GB']:
        if bytes_size < 1024:
            return f"{bytes_size:.1f} {unit}"
        bytes_size /= 1024
    return f"{bytes_size:.1f} TB"


def main():
    """Main entry point."""
    print("\n" + "=" * 50)
    print("  Obsidian Note Mover (Simple)")
    print("  Move notes based on tags")
    print("=" * 50)

    # Interactive prompts
    print("\n[Step 1] Source Directory")
    source_input = input(f"Path [{SOURCE_DIR}]: ").strip()
    source_dir = Path(source_input).expanduser() if source_input else SOURCE_DIR

    if not source_dir.exists():
        print(f"Error: Path does not exist: {source_dir}")
        return

    print(f"Found: {len(list(source_dir.rglob('*.md')))} markdown files")

    print("\n[Step 2] Destination Directory")
    dest_input = input(f"Path [{DEST_DIR}]: ").strip()
    dest_dir = Path(dest_input).expanduser() if dest_input else DEST_DIR

    # Create destination if needed
    if not dest_dir.exists():
        if input(f"Create {dest_dir}? [y/N]: ").strip().lower() == 'y':
            dest_dir.mkdir(parents=True, exist_ok=True)
        else:
            return

    print("\n[Step 3] Trigger Tag")
    tag_input = input(f"Tag to search for [{TRIGGER_TAG}]: ").strip()
    trigger_tag = tag_input if tag_input else TRIGGER_TAG

    print("\n[Step 4] Scan & Preview")
    notes = scan_notes(source_dir, trigger_tag, EXCLUDED_DIRS)

    if not notes:
        print(f"No notes found with tag: {trigger_tag}")
        return

    print(f"Found {len(notes)} matching notes:\n")
    total_size = 0
    total_attachments = 0

    for i, (note_path, text) in enumerate(notes[:20], 1):
        size = note_path.stat().st_size
        total_size += size
        rel_path = note_path.relative_to(source_dir)
        attachments = find_attachments(text, note_path.parent)
        total_attachments += len(attachments)

        print(f"  {i}. {rel_path}")
        print(f"     Size: {format_size(size)} | Attachments: {len(attachments)}")

    if len(notes) > 20:
        print(f"\n  ... and {len(notes) - 20} more")

    print(f"\nTotal: {len(notes)} notes, {total_attachments} attachments, {format_size(total_size)}")

    # Confirm
    if input("\nMove these notes? [y/N]: ").strip().lower() != 'y':
        print("Cancelled")
        return

    # Move notes
    print("\n[Moving]")
    moved = 0
    moved_attachments = 0
    errors = 0

    for i, (note_path, text) in enumerate(notes, 1):
        rel_path = note_path.relative_to(source_dir)
        print(f"  [{i}/{len(notes)}] {rel_path}...", end="", flush=True)

        try:
            # Move attachments
            attachments = find_attachments(text, note_path.parent)
            for attachment in attachments:
                shutil.move(attachment, dest_dir / attachment.name)
                moved_attachments += 1

            # Move note
            shutil.move(note_path, dest_dir / note_path.name)
            moved += 1
            print(f" ✓ (+{len(attachments)} attachments)")

        except Exception as e:
            errors += 1
            print(f" ✗ Error: {e}")

    # Summary
    print("\n" + "=" * 50)
    print("  Complete!")
    print(f"  Notes moved: {moved}")
    print(f"  Attachments moved: {moved_attachments}")
    print(f"  Errors: {errors}")
    print("=" * 50 + "\n")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\nInterrupted")
    except Exception as e:
        print(f"\n\nError: {e}")
