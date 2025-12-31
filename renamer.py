#!/usr/bin/env python3
"""
🚀 Advanced File Renamer (Ultra Optimized)
A high-performance, intelligent file renaming tool with PDF metadata extraction,
rich CLI visualization, and history tracking for undos.

# Standard run (clean up files in current dir)
python3 renamer.py .

# Recursive scan with dry run
python3 renamer.py /path/to/books -r --dry-run

# Specific extensions only
python3 renamer.py /downloads -e pdf epub mobi

# Undo the last session
python3 renamer.py /path/to/books --undo
"""

import re
import sys
import json
import argparse
import logging
import concurrent.futures
from pathlib import Path
from typing import List, Dict, Tuple, Optional, Any, Set
from dataclasses import dataclass, field
from datetime import datetime

# Third-party libraries
try:
    import fitz  # PyMuPDF
except ImportError:
    fitz = None

try:
    from rich.console import Console
    from rich.table import Table
    from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn, TaskProgressColumn
    from rich.panel import Panel
    from rich.theme import Theme
    from rich.logging import RichHandler
    from rich import print as rprint
except ImportError:
    # Fallback to standard print if rich is missing (though we checked it's present)
    Console = None

# Custom Theme
THEME = Theme({
    "info": "cyan",
    "warning": "yellow",
    "error": "red",
    "success": "green",
    "brand": "bold magenta",
    "dim": "grey50"
})

console = Console(theme=THEME) if Console else None

# Setup Logging
logging.basicConfig(
    level=logging.INFO,
    format="%(message)s",
    datefmt="[%X]",
    handlers=[RichHandler(rich_tracebacks=True, console=console)] if console else [logging.StreamHandler()]
)
log = logging.getLogger("renamer")

@dataclass
class RenamerConfig:
    """Configuration for the FileRenamer."""
    directory: Path
    dry_run: bool = False
    extensions: Optional[List[str]] = None
    verbose: bool = False
    recursive: bool = False
    extract_metadata: bool = True
    save_history: bool = True
    title_case: bool = True

class HistoryManager:
    """Manages renaming history for undo functionality."""
    def __init__(self, history_file: Path):
        self.history_file = history_file
        self.history: List[Dict[str, str]] = []

    def record(self, original: Path, renamed: Path):
        self.history.append({
            "timestamp": datetime.now().isoformat(),
            "original": str(original.absolute()),
            "renamed": str(renamed.absolute())
        })

    def save(self):
        if not self.history:
            return
        
        existing_history = []
        if self.history_file.exists():
            try:
                with open(self.history_file, 'r') as f:
                    existing_history = json.load(f)
            except Exception:
                pass
        
        combined = existing_history + self.history
        try:
            with open(self.history_file, 'w') as f:
                json.dump(combined, f, indent=2)
            log.debug(f"History saved to {self.history_file}")
        except Exception as e:
            log.error(f"Failed to save history: {e}")

class FileRenamer:
    """Advanced pattern-based file renamer with parallel execution."""
    
    DEFAULT_EXTENSIONS: Set[str] = {
        '.pdf', '.epub', '.mobi', '.azw3', '.doc', '.docx', '.txt', '.mp4', '.mkv'
    }
    
    # Junk patterns commonly found in downloads
    JUNK_PATTERNS: List[str] = [
        r'\s*\(?(?:z-lib|libgen|books|early release|ebooks|pdfdrive|docer|annas-archive)[^)]*\)?',
        r'\s*\[(?:digital-only|hq|optimized|scan|ocr|rip|h264|x264|1080p|720p|z-lib|libgen|pdfdrive)[^\]]*\]',
        r'\s*\((?:epub|pdf|mobi|azw3)\s*(?:version|format)[^)]*\)',
        r'\s*v\d+(?:\.\d+){1,2}', # version numbers
        r'\s*-\s*[a-fA-F0-9]{8,}', # hashes
        r'\s*-(?:\s*|$)_?(?:\d{1,4}[kK]?)', # -10k, -001, etc
        r'\s*\.(?:com|org|net|edu|biz|info|site|me|top|xyz|io)', # websites
        r'\s*(?:uploaded_by|downloaded_from)[^ ]*',
        r'\s*\d{1,2}(?:st|nd|rd|th)?\s+Ed(?:\.|\b)', # 2nd Ed
    ]

    METADATA_KEYWORDS: Set[str] = {
        'edition', 'volume', 'revised', 'updated', 'complete', 'guide', 
        'handbook', 'manual', 'version', 'volume', 'part', 'chapter', 'series'
    }

    def __init__(self, config: RenamerConfig):
        self.config = config
        self.supported_extensions = {
            ext.lower() if ext.startswith('.') else f".{ext.lower()}" 
            for ext in (config.extensions or self.DEFAULT_EXTENSIONS)
        }
        
        # Compile patterns
        self.compiled_junk = [re.compile(p, re.IGNORECASE) for p in self.JUNK_PATTERNS]
        self.compiled_metadata = [re.compile(rf'\b{re.escape(k)}\b', re.IGNORECASE) for k in self.METADATA_KEYWORDS]
        self.compiled_spaces = re.compile(r'\s+')
        
        self.history_manager = HistoryManager(config.directory / ".renamer_history.json")
        
        if config.verbose:
            log.setLevel(logging.DEBUG)

    def _to_title_case(self, text: str) -> str:
        """Convert string to Title Case while preserving acronyms."""
        words = text.split()
        title_words = []
        for word in words:
            # If word is already all caps and > 1 char, it might be an acronym (like AWS, PDF)
            if word.isupper() and len(word) > 1:
                title_words.append(word)
            else:
                title_words.append(word.capitalize())
        return " ".join(title_words)

    def extract_pdf_metadata(self, path: Path) -> Optional[str]:
        """Try to extract title from PDF metadata."""
        if not fitz or path.suffix.lower() != '.pdf':
            return None
        
        try:
            with fitz.open(path) as doc:
                meta = doc.metadata
                title = meta.get('title')
                author = meta.get('author')
                
                if title and len(title.strip()) > 5:
                    clean_title = title.strip()
                    if author and len(author.strip()) > 3:
                        return f"{clean_title} - {author.strip()}"
                    return clean_title
        except Exception as e:
            log.debug(f"Metadata extraction failed for {path.name}: {e}")
        return None

    def clean_name(self, filepath: Path) -> str:
        """Core cleaning logic with metadata enhancement."""
        stem = filepath.stem
        original = stem
        
        # 1. Try metadata extraction first if filename is mostly digits or very short
        if self.config.extract_metadata and (stem.isdigit() or len(stem) < 10):
            meta_title = self.extract_pdf_metadata(filepath)
            if meta_title:
                stem = meta_title

        # Pre-process: Replace underscores and dots with spaces
        name = stem.replace('_', ' ').replace('.', ' ')
        
        # 1. Strip known junk
        for pattern in self.compiled_junk:
            name = pattern.sub(' ', name)
            
        # 2. Extract Author/Title parts
        name = self._heuristic_splitting(name)
        
        # 3. Final Sanitize
        # Remove illegal path chars and remaining bracket/paren debris
        name = re.sub(r'[<>:"/\\|?*()\[\]]', ' ', name)
        name = self.compiled_spaces.sub(' ', name).strip()
        
        # 4. Title Case
        if self.config.title_case:
            name = self._to_title_case(name)

        # 5. Fix common punctuation issues (e.g. "Title - - Author" or "Title , Author")
        name = re.sub(r'\s*-\s*', ' - ', name)
        name = re.sub(r'\s*,\s*', ', ', name)
        name = re.sub(r'\w+-\w+', lambda m: m.group(0), name) # Preserve hyphens in words like "multi-step"
        name = self.compiled_spaces.sub(' ', name).strip()
            
        return name if name and len(name) > 2 else original

    def _heuristic_splitting(self, text: str) -> str:
        """Splits text into Title - Author based on heuristics."""
        
        # Pattern: Title (Author)
        match_paren = re.search(r'^(.+?)\s*\(([^)]+)\)', text)
        if match_paren:
            title, author = match_paren.group(1).strip(), match_paren.group(2).strip()
            if self._is_author(author):
                return f"{title} - {author}"
                
        # Pattern: Title by Author
        match_by = re.search(r'^(.+?)\s+by\s+(.+)', text, re.IGNORECASE)
        if match_by:
            return f"{match_by.group(1).strip()} - {match_by.group(2).strip()}"
            
        # Pattern: Author - Title (Standardize to Title - Author)
        if ' - ' in text:
            parts = [p.strip() for p in text.split(' - ', 1)]
            if len(parts) == 2:
                if self._is_author(parts[0]) and not self._is_author(parts[1]):
                    # Check if it's already Title - Author (heuristic: author name usually 2-3 words)
                    return f"{parts[1]} - {parts[0]}"
                return f"{parts[0]} - {parts[1]}"
                
        return text

    def _is_author(self, text: str) -> bool:
        """Heuristic to determine if text fragment is an author name."""
        words = text.split()
        if not (1 <= len(words) <= 4): return False
        
        # If it contains numbers, probably not an author
        if any(char.isdigit() for char in text):
            return False

        # Check against metadata keywords
        if any(p.search(text) for p in self.compiled_metadata):
            return False
            
        # Check for capitalization (Author names should be capitalized)
        proper_nouns = sum(1 for w in words if w and w[0].isupper() and w.isalpha())
        # For single word names, treat as potential author if capitalized
        if len(words) == 1:
            return words[0][0].isupper()
            
        return proper_nouns >= 1

    def process_file(self, filepath: Path) -> Dict[str, Any]:
        """Processes a single file. Returns result metadata."""
        try:
            old_name = filepath.name
            old_stem = filepath.stem
            ext = filepath.suffix
            
            new_stem = self.clean_name(filepath)
            
            if new_stem == old_stem:
                return {"path": filepath, "new_name": None, "status": "skipped"}
                
            new_name = f"{new_stem}{ext}"
            new_path = filepath.parent / new_name
            
            # Conflict resolution
            if new_path.exists() and new_path.absolute() != filepath.absolute():
                counter = 1
                while True:
                    candidate = filepath.parent / f"{new_stem}_{counter}{ext}"
                    if not candidate.exists():
                        new_path = candidate
                        break
                    counter += 1
            
            if not self.config.dry_run:
                filepath.rename(new_path)
                if self.config.save_history:
                    self.history_manager.record(filepath, new_path)
                
            return {
                "path": filepath, 
                "old_name": old_name,
                "new_name": new_path.name, 
                "status": "renamed"
            }
            
        except Exception as e:
            return {"path": filepath, "error": str(e), "status": "error"}

    def run(self):
        """Orchestrates parallel renaming with rich output."""
        files = []
        pattern = "**/*" if self.config.recursive else "*"
        for f in self.config.directory.glob(pattern):
            if f.is_file() and f.suffix.lower() in self.supported_extensions and not f.name.startswith('.'):
                files.append(f)
                
        if not files:
            rprint(f"[success]✓[/] No files requiring processing in [dim]{self.config.directory}[/]")
            return

        if console:
            console.print(Panel(
                f"Found [bold]{len(files)}[/] files to analyze.\n"
                f"Extensions: {', '.join(self.supported_extensions)}\n"
                f"Mode: {'[warning]DRY RUN[/]' if self.config.dry_run else '[success]LIVE[/]'}",
                title="🚀 Renamer Initialization",
                expand=False
            ))

        results_list = []
        
        # Parallel Execution with Progress Bar
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            BarColumn(),
            TaskProgressColumn(),
            console=console
        ) as progress:
            task = progress.add_task("Processing files...", total=len(files))
            
            with concurrent.futures.ThreadPoolExecutor() as executor:
                futures = {executor.submit(self.process_file, f): f for f in files}
                for future in concurrent.futures.as_completed(futures):
                    results_list.append(future.result())
                    progress.advance(task)

        # Summary Table
        table = Table(title="Renaming Summary", show_header=True, header_style="bold magenta")
        table.add_column("Original Name", style="dim", no_wrap=False)
        table.add_column("New Name", style="success")
        table.add_column("Status", justify="right")

        renamed_count = 0
        error_count = 0
        skipped_count = 0

        for res in results_list:
            if res["status"] == "renamed":
                table.add_row(res["old_name"], res["new_name"], "[success]Renamed[/]")
                renamed_count += 1
            elif res["status"] == "error":
                table.add_row(res["path"].name, res["error"], "[error]FAILED[/]")
                error_count += 1
            else:
                skipped_count += 1

        if renamed_count > 0 or error_count > 0:
            if console:
                console.print(table)
        
        final_summary = (
            f"\n  [success]Renamed:[/] {renamed_count}"
            f"\n  [error]Errors:[/]  {error_count}"
            f"\n  [dim]Skipped:[/] {skipped_count}"
        )
        if console:
            console.print(Panel(final_summary, title="📊 Final Totals", expand=False))
        else:
            print(final_summary)

        if self.config.save_history and not self.config.dry_run:
            self.history_manager.save()

def undo_last_session(directory: Path):
    """Reverts changes from the last session using the history file."""
    history_file = directory / ".renamer_history.json"
    if not history_file.exists():
        rprint("[error]❌ No history file found in this directory.[/]")
        return

    try:
        with open(history_file, 'r') as f:
            history = json.load(f)
    except Exception as e:
        rprint(f"[error]❌ Failed to read history: {e}[/]")
        return

    if not history:
        rprint("[warning]⚠ History is empty.[/]")
        return

    rprint(f"Found [bold]{len(history)}[/] rename operations to undo.")
    
    # Sort history by timestamp descending to undo from newest to oldest
    history.sort(key=lambda x: x.get('timestamp', ''), reverse=True)

    undone_count = 0
    for entry in history:
        original = Path(entry['original'])
        renamed = Path(entry['renamed'])

        if renamed.exists():
            try:
                renamed.rename(original)
                undone_count += 1
            except Exception as e:
                rprint(f"  [error]⚠ Failed to undo {renamed.name}: {e}[/]")
        else:
            rprint(f"  [dim]Skipped: {renamed.name} (not found)[/]")

    rprint(f"[success]✓ Successfully reverted {undone_count} files.[/]")
    # Optionally clear history or mark as undone
    history_file.unlink()

def main():
    parser = argparse.ArgumentParser(description="🚀 Ultra-Optimized Professional File Renamer")
    parser.add_argument("directory", nargs="?", help="Target directory")
    parser.add_argument("--dry-run", action="store_true", help="Simulate changes without applying")
    parser.add_argument("--recursive", "-r", action="store_true", help="Recursive scan of subdirectories")
    parser.add_argument("--extensions", "-e", nargs="+", help="Explicit extensions (e.g., pdf epub)")
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose logging")
    parser.add_argument("--undo", action="store_true", help="Undo the last renaming session")
    parser.add_argument("--no-meta", action="store_false", dest="extract_metadata", help="Disable PDF metadata extraction")
    parser.add_argument("--no-history", action="store_false", dest="save_history", help="Don't save rename history")
    
    args = parser.parse_args()
    
    # Path resolution
    if not args.directory:
        if args.undo:
            dir_input = input("Enter directory path to undo: ").strip()
        else:
            dir_input = input("Enter directory path to process: ").strip()
        
        if not dir_input:
            dir_input = "."
        directory = Path(dir_input).expanduser().resolve()
    else:
        directory = Path(args.directory).expanduser().resolve()
        
    if not directory.is_dir():
        rprint(f"[error]❌ Error: {directory} is not a directory.[/]")
        sys.exit(1)

    if args.undo:
        undo_last_session(directory)
        return
        
    config = RenamerConfig(
        directory=directory,
        dry_run=args.dry_run,
        recursive=args.recursive,
        extensions=args.extensions,
        verbose=args.verbose,
        extract_metadata=args.extract_metadata,
        save_history=args.save_history
    )
    
    renamer = FileRenamer(config)
    
    if config.dry_run:
        rprint("[brand]⭐ DRY RUN MODE ACTIVE - No changes will be saved[/]")
        
    renamer.run()

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        rprint("\n[warning]👋 Operation cancelled by user.[/]")
    except Exception as e:
        log.exception(f"Fatal error: {e}")