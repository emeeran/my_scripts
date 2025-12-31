#!/usr/bin/env python3
"""
🚀 High-Performance File Sorter
Recursively sorts files by extension into organized subdirectories with parallel execution.
"""

import shutil
import concurrent.futures
from pathlib import Path
import sys
from typing import List, Tuple, Optional
from datetime import datetime
from dataclasses import dataclass

@dataclass
class SortResult:
    status: str
    original: Path
    target: Path
    error: Optional[str] = None

def format_size(bytes_size: int) -> str:
    """Format bytes to human readable size."""
    for unit in ['B', 'KB', 'MB', 'GB']:
        if bytes_size < 1024:
            return f"{bytes_size:.1f} {unit}"
        bytes_size /= 1024
    return f"{bytes_size:.1f} TB"

def get_unique_path(path: Path) -> Path:
    """Generate a unique path by appending an incremental counter."""
    if not path.exists():
        return path
    
    base, suffix = path.stem, path.suffix
    parent = path.parent
    counter = 1
    while True:
        new_path = parent / f"{base}_{counter}{suffix}"
        if not new_path.exists():
            return new_path
        counter += 1

class FileSorter:
    def __init__(self, source: Path, destination: Path, dry_run: bool = False):
        self.source = source.resolve()
        self.destination = destination.resolve()
        self.dry_run = dry_run
        self.duplicates_dir = self.destination / "collisions"
        
    def process_file(self, file_path: Path) -> SortResult:
        """Move a single file to its extension-based folder."""
        try:
            # Skip files already in the destination
            if self.destination in file_path.parents:
                return SortResult("SKIPPED", file_path, file_path)

            ext = file_path.suffix.lower().lstrip(".") or "no_extension"
            target_dir = self.destination / ext
            target_path = target_dir / file_path.name
            
            status = "MOVED"
            if target_path.exists():
                # If target exists, move to collisions folder with unique name
                target_dir = self.duplicates_dir
                target_path = get_unique_path(target_dir / file_path.name)
                status = "COLLISION"

            if not self.dry_run:
                target_dir.mkdir(parents=True, exist_ok=True)
                shutil.move(str(file_path), str(target_path))
                
            return SortResult(status, file_path, target_path)
            
        except Exception as e:
            return SortResult("ERROR", file_path, file_path, error=str(e))

    def run(self):
        print_header(f"{'[SIMULATION]' if self.dry_run else '[ACTION]'} Sorting Vault")
        
        # 1. Scanning
        print(f"  🔍 Scanning recursive source: {self.source.name}...")
        all_files = [p for p in self.source.rglob("*") if p.is_file()]
        
        if not all_files:
            print("  ✓ No files found to sort.")
            return

        print(f"  📦 Found {len(all_files)} files. Starting parallel execution...")

        # 2. Parallel Sort
        results = []
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
            futures = [executor.submit(self.process_file, f) for f in all_files]
            
            for i, future in enumerate(concurrent.futures.as_completed(futures), 1):
                res = future.result()
                results.append(res)
                print(f"  🚀 Progress: {i}/{len(all_files)} | Last: {res.original.name[:25]}", end="\r")

        # 3. Summary
        print("\n\n" + "-"*60)
        moved = sum(1 for r in results if r.status == "MOVED")
        collisions = sum(1 for r in results if r.status == "COLLISION")
        errors = sum(1 for r in results if r.status == "ERROR")
        
        print(f"  ✅ Successfully Processed: {moved}")
        if collisions:
            print(f"  ⚠️  Collisions (Renamed):   {collisions}")
        if errors:
            print(f"  ❌ Errors Encountered:   {errors}")
            
        if not self.dry_run:
            print(f"\n  ✨ Organized vault: {self.destination}")
        else:
            print("\n  📝 Dry run complete. No files were physically moved.")

def print_header(title: str):
    print(f"\n{'=' * 60}")
    print(f"  {title}")
    print('=' * 60)

def main():
    print_header("Turbo File Sorter Pro")
    
    src_input = input("  Enter SOURCE directory: ").strip() or "."
    dst_input = input("  Enter DESTINATION: ").strip() or "./Sorted"
    
    source = Path(src_input).expanduser().resolve()
    destination = Path(dst_input).expanduser().resolve()
    
    if not source.is_dir():
        print(f"  ❌ Error: Source '{source}' is not a directory.")
        return

    print(f"\n  Source: {source}")
    print(f"  Target: {destination}")
    
    while True:
        print("\n  Options:")
        print("  1. Preview (Dry Run)")
        print("  2. Execute Sort (Physical Move)")
        print("  3. Exit")
        
        choice = input("\n  Select Option (1-3): ").strip()
        
        if choice == '1':
            FileSorter(source, destination, dry_run=True).run()
        elif choice == '2':
            confirm = input("  ⚠️  FILES WILL BE MOVED. Proceed? (y/n): ").lower()
            if confirm == 'y':
                FileSorter(source, destination, dry_run=False).run()
        elif choice == '3':
            print("  👋 Goodbye!")
            break
        else:
            print("  ❌ Invalid choice.")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n  👋 Interrupted by user.")
    except Exception as e:
        print(f"\n\n  💥 Fatal System Error: {e}")
        import traceback
        traceback.print_exc()

