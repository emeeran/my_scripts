#!/usr/bin/env python3
"""Interactive File Mover - Move files by extension filter.

A standalone script to move files based on file extensions.
Supports multiple extensions and recursive directory scanning.

Usage:
    python move_files.py
"""

import re
import shutil
import concurrent.futures
from pathlib import Path
from dataclasses import dataclass
from typing import List, Set, Optional, Dict, Tuple
from datetime import datetime

@dataclass
class FileMetadata:
    path: Path
    rel_path: Path
    extension: str
    size: int

def print_header(title: str):
    """Print a section header."""
    print(f"\n{'=' * 60}")
    print(f"  {title}")
    print('=' * 60)


def format_size(bytes_size: int) -> str:
    """Format bytes to human readable size."""
    for unit in ['B', 'KB', 'MB', 'GB']:
        if bytes_size < 1024:
            return f"{bytes_size:.1f} {unit}"
        bytes_size /= 1024
    return f"{bytes_size:.1f} TB"


def parse_extensions(input_str: str) -> List[str]:
    """Parse extension input from user."""
    exts = re.findall(r'\.?(\w+)', input_str)
    return [f".{ext.lower()}" if not ext.startswith('.') else ext.lower() for ext in exts]


def get_path_metadata(file_path: Path, source_dir: Path) -> FileMetadata:
    """Extract metadata for a single file."""
    return FileMetadata(
        path=file_path,
        rel_path=file_path.relative_to(source_dir),
        extension=file_path.suffix.lower(),
        size=file_path.stat().st_size
    )


def scan_files_parallel(source_dir: Path, extensions: Set[str], excluded_dirs: Set[str], recursive: bool) -> List[FileMetadata]:
    """Scan for files in parallel."""
    print(f"  🔍 Indexing directory...")
    
    # Selection logic based on recursiveness
    pattern = "**/*" if recursive else "*"
    
    # Filter paths first to avoid expensive stat calls on everything
    candidate_paths = []
    for p in source_dir.glob(pattern):
        if p.is_file() and not any(excl in p.parts for excl in excluded_dirs):
            if p.suffix.lower() in extensions:
                candidate_paths.append(p)

    results = []
    with concurrent.futures.ThreadPoolExecutor() as executor:
        futures = [executor.submit(get_path_metadata, p, source_dir) for p in candidate_paths]
        for future in concurrent.futures.as_completed(futures):
            results.append(future.result())
            
    return sorted(results, key=lambda x: x.rel_path)


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


def confirm_action(message: str) -> bool:
    """Ask user for yes/no confirmation."""
    response = input(f"\n{message} [y/N]: ").strip().lower()
    return response in ('y', 'yes')


def move_task(file_meta: FileMetadata, dest_dir: Path, org_choice: str, dry_run: bool) -> Tuple[bool, str]:
    """Single file move task for parallel execution."""
    try:
        if org_choice == "1": # Flatten
            dest = dest_dir / file_meta.path.name
        else: # Preserve
            dest = dest_dir / file_meta.rel_path
            
        # Conflict resolution
        if dest.exists():
            base = dest.stem
            ext = dest.suffix
            counter = 1
            while dest.exists():
                dest = dest.with_name(f"{base}_{counter}{ext}")
                counter += 1

        if not dry_run:
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(file_meta.path, dest)
            
        return True, f"Moved {file_meta.rel_path} -> {dest.name}"
    except Exception as e:
        return False, str(e)


def main():
    print("\n" + "=" * 60)
    print("  🚀 Professional File Mover (Optimized)")
    print("=" * 60)

    # STEP 1: CONFIGURATION
    print_header("Step 1: Path Configuration")
    source_dir = get_path_input("  Source directory", Path.cwd(), must_exist=True)
    dest_dir = get_path_input("  Destination directory", Path.home() / "Downloads/Sorted", must_exist=False)

    if not dest_dir.exists():
        if confirm_action(f"  Create directory: {dest_dir}?"):
            dest_dir.mkdir(parents=True, exist_ok=True)
        else: return

    # STEP 2: FILTERS
    print_header("Step 2: Filter Configuration")
    ext_input = input("\n  Extensions (e.g. .pdf .png or pdf png): ").strip()
    extensions = set(parse_extensions(ext_input)) or {".pdf", ".jpg", ".png"}
    print(f"  ✓ Target: {', '.join(extensions)}")

    recursive = confirm_action("  Scan subdirectories recursively?")
    
    exclude_input = input("  Exclude (comma-sep) [.git, .venv, node_modules]: ").strip()
    excluded_dirs = set(d.strip() for d in exclude_input.split(",")) if exclude_input else {".git", ".venv", "node_modules", ".obsidian"}

    # STEP 3: SCAN
    print_header("Step 3: Scanning & Analysis")
    files = scan_files_parallel(source_dir, extensions, excluded_dirs, recursive)

    if not files:
        print("  ❌ No matching files found.")
        return

    # Statistics
    total_size = sum(f.size for f in files)
    by_ext_stats = {}
    for f in files:
        by_ext_stats[f.extension] = by_ext_stats.get(f.extension, 0) + 1

    print(f"\n  Found {len(files)} files totaling {format_size(total_size)}")
    for ext, count in sorted(by_ext_stats.items()):
        print(f"    - {ext}: {count} files")

    # STEP 4: OPERATION MODE
    print_header("Step 4: Operation Mode")
    print("  1. Flatten structure (all files in destination root)")
    print("  2. Preserve folder structure")
    org_choice = input("  Organization Choice [1]: ").strip() or "1"
    
    dry_run = confirm_action("  Enable DRY RUN mode? (No files will be moved)")

    if not confirm_action(f"  Execute {'dry run' if dry_run else 'move'} now?"):
        print("  Cancelled.")
        return

    # STEP 5: EXECUTION
    print_header("Step 5: Execution")
    success_count = 0
    error_count = 0
    
    # Use thread pool for moving (IO bound)
    # Note: We limit workers for moving to avoid extreme disk contention depending on storage type
    max_move_workers = 8 
    
    with concurrent.futures.ThreadPoolExecutor(max_workers=max_move_workers) as executor:
        futures = [executor.submit(move_task, f, dest_dir, org_choice, dry_run) for f in files]
        
        for i, future in enumerate(concurrent.futures.as_completed(futures), 1):
            success, message = future.result()
            if success:
                success_count += 1
            else:
                error_count += 1
                print(f"\n  ❌ Error: {message}")
            
            print(f"  🚀 Progress: [{i}/{len(files)}] {'(Simulated)' if dry_run else ''}", end="\r")

    # STEP 6: FINAL SUMMARY
    print_header("Operation Complete")
    status = "SIMULATED" if dry_run else "MOVED"
    print(f"  Total files processed: {len(files)}")
    print(f"  Successfully {status.lower()}: {success_count}")
    if error_count:
        print(f"  Errors encountered: {error_count}")
        
    log_name = f"move_log_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
    if not dry_run:
        print(f"\n  ✅ Files have been moved to: {dest_dir}")
    else:
        print(f"\n  📝 Dry run complete. No changes were made.")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n  👋 Interrupted by user. Exiting...")
    except Exception as e:
        print(f"\n\n  💥 Unexpected system error: {e}")
        import traceback
        traceback.print_exc()
