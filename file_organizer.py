"""
🚀 High-Performance Automatic File Organizer
Organizes files into structured categories with parallel execution and safety features.
"""

import re
import shutil
import concurrent.futures
import json
from pathlib import Path
from datetime import datetime
from dataclasses import dataclass, asdict
from typing import List, Set, Dict, Optional, Tuple

@dataclass
class MoveOperation:
    timestamp: str
    filename: str
    original: str
    new_location: str
    category: str
    size: int

def format_size(bytes_size: int) -> str:
    """Format bytes to human readable size."""
    for unit in ['B', 'KB', 'MB', 'GB']:
        if bytes_size < 1024:
            return f"{bytes_size:.1f} {unit}"
        bytes_size /= 1024
    return f"{bytes_size:.1f} TB"

class FileOrganizer:
    def __init__(self, source_dir: Path, recursive: bool = False, create_date_folders: bool = False):
        self.source_dir = Path(source_dir).expanduser().resolve()
        self.recursive = recursive
        self.create_date_folders = create_date_folders
        self.log_file = self.source_dir / f"org_log_{datetime.now().strftime('%Y%m%d')}.json"
        
        # Extended File type categories
        self.categories = {
            'Images': {'.jpg', '.jpeg', '.png', '.gif', '.bmp', '.svg', '.webp', '.tiff', '.heic', '.raw'},
            'Documents': {'.pdf', '.doc', '.docx', '.txt', '.pages', '.odt', '.xls', '.xlsx', '.csv', '.ppt', '.pptx', '.md', '.epub'},
            'Videos': {'.mp4', '.avi', '.mkv', '.mov', '.wmv', '.flv', '.webm', '.m4v'},
            'Audio': {'.mp3', '.wav', '.flac', '.aac', '.ogg', '.wma', '.m4a', '.aiff'},
            'Archives': {'.zip', '.rar', '.7z', '.tar', '.gz', '.bz2', '.xz'},
            'Code': {'.py', '.js', '.ts', '.html', '.css', '.java', '.cpp', '.c', '.cs', '.go', '.rs', '.json', '.yaml', '.yml', '.sql'},
            'Executables': {'.exe', '.dmg', '.pkg', '.deb', '.rpm', '.msi', '.sh', '.bin'},
            'Design': {'.psd', '.ai', '.fig', '.sketch', '.xd'},
        }

    def get_category(self, file_path: Path) -> str:
        ext = file_path.suffix.lower()
        for category, extensions in self.categories.items():
            if ext in extensions:
                return category
        return 'Others'

    def get_safe_path(self, target_path: Path) -> Path:
        """Collision resolution: file.txt -> file_1.txt"""
        if not target_path.exists():
            return target_path
        
        stem = target_path.stem
        suffix = target_path.suffix
        parent = target_path.parent
        counter = 1
        
        while True:
            new_path = parent / f"{stem}_{counter}{suffix}"
            if not new_path.exists():
                return new_path
            counter += 1

    def move_single_file(self, file_path: Path, dry_run: bool) -> Optional[MoveOperation]:
        """Task for parallel execution."""
        try:
            if file_path == self.log_file or file_path.name.startswith("org_log_"):
                return None

            category = self.get_category(file_path)
            
            # Determine base destination (don't move into existing category folders to avoid loops)
            dest_root = self.source_dir / category
            
            if self.create_date_folders:
                mtime = datetime.fromtimestamp(file_path.stat().st_mtime)
                dest_root = dest_root / mtime.strftime("%Y-%m")

            target_path = self.get_safe_path(dest_root / file_path.name)

            if not dry_run:
                target_path.parent.mkdir(parents=True, exist_ok=True)
                # Use move or copy+delete logic? shutil.move is efficient
                shutil.move(file_path, target_path)

            return MoveOperation(
                timestamp=datetime.now().isoformat(),
                filename=file_path.name,
                original=str(file_path),
                new_location=str(target_path),
                category=category,
                size=file_path.stat().st_size if not dry_run else 0 # stats might change after move
            )
        except Exception as e:
            print(f"\n  ❌ Failed: {file_path.name} -> {e}")
            return None

    def run(self, dry_run: bool = True):
        print(f"\n{'[SIMULATION]' if dry_run else '[ACTION]'} Organizing: {self.source_dir}")
        
        # 1. Scan
        pattern = "**/*" if self.recursive else "*"
        all_items = list(self.source_dir.glob(pattern))
        files = [f for f in all_items if f.is_file() and not any(cat in f.parts for cat in self.categories)]
        
        if not files:
            print("  ✓ No new files to organize.")
            return

        print(f"  🔍 Found {len(files)} files to process...")

        # 2. Execute in Parallel
        results = []
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
            futures = [executor.submit(self.move_single_file, f, dry_run) for f in files]
            for i, future in enumerate(concurrent.futures.as_completed(futures), 1):
                res = future.result()
                if res:
                    results.append(res)
                print(f"  🚀 Progress: {i}/{len(files)}", end="\r")

        # 3. Summary & Logging
        print(f"\n\n  ✅ Done! Processed {len(results)} files.")
        
        if not dry_run and results:
            log_data = [asdict(r) for r in results]
            with open(self.log_file, 'w') as f:
                json.dump(log_data, f, indent=2)
            print(f"  📝 Log saved: {self.log_file.name}")

def print_header(text: str):
    print(f"\n{'='*60}\n  {text}\n{'='*60}")

def main():
    import sys
    
    path_arg = sys.argv[1] if len(sys.argv) > 1 else str(Path.home() / "Downloads")
    source = Path(path_arg).expanduser().resolve()
    
    if not source.is_dir():
        print(f"❌ Error: {source} is not a directory.")
        return

    organizer = FileOrganizer(source)
    
    while True:
        print_header("File Organizer Pro")
        print(f" Current Path: {source}")
        print(f" Recursive:    {organizer.recursive}")
        print(f" Date Folders: {organizer.create_date_folders}")
        print("-" * 60)
        print("  1. Preview (Dry Run)")
        print("  2. Organize Files")
        print("  3. Toggle Recursive Scan")
        print("  4. Toggle Date-Based Subfolders")
        print("  5. Change Directory")
        print("  6. Exit")
        
        choice = input("\nSelect an option (1-6): ").strip()
        
        if choice == '1':
            organizer.run(dry_run=True)
        elif choice == '2':
            confirm = input("⚠️  Move files now? (y/n): ").lower()
            if confirm == 'y':
                organizer.run(dry_run=False)
        elif choice == '3':
            organizer.recursive = not organizer.recursive
            print(f"✓ Recursive scanning: {'ON' if organizer.recursive else 'OFF'}")
        elif choice == '4':
            organizer.create_date_folders = not organizer.create_date_folders
            print(f"✓ Date folders: {'ON' if organizer.create_date_folders else 'OFF'}")
        elif choice == '5':
            new_path = input("Enter new path: ").strip()
            if Path(new_path).expanduser().is_dir():
                source = Path(new_path).expanduser().resolve()
                organizer = FileOrganizer(source)
            else:
                print("❌ Invalid directory.")
        elif choice == '6':
            print("👋 Goodbye!")
            break
        else:
            print("Invalid choice.")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n👋 Interrupted by user.")
    except Exception as e:
        print(f"\n\n💥 Fatal Error: {e}")


