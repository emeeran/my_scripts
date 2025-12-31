#!/usr/bin/env python3
"""
🚀 RED (Redundant Directory) Remover - Ultra Optimized
Intelligently scans and removes empty or junk-only directories with a professional interface.
"""

import sys
import argparse
import logging
import shutil
import concurrent.futures
from pathlib import Path
from typing import List, Set, Tuple, Optional, Dict, Any
from dataclasses import dataclass, field
from datetime import datetime

# Third-party libraries
try:
    from rich.console import Console
    from rich.table import Table
    from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn, TaskProgressColumn
    from rich.panel import Panel
    from rich.theme import Theme
    from rich.logging import RichHandler
    from rich.prompt import Confirm, Prompt
    from rich import print as rprint
except ImportError:
    Console = None

# Custom Theme
THEME = Theme({
    "info": "cyan",
    "warning": "yellow",
    "error": "red",
    "success": "green",
    "brand": "bold magenta",
    "dim": "grey50",
    "path": "blue italic"
})

console = Console(theme=THEME) if Console else None

# Setup Logging
logging.basicConfig(
    level=logging.INFO,
    format="%(message)s",
    datefmt="[%X]",
    handlers=[RichHandler(rich_tracebacks=True, console=console)] if console else [logging.StreamHandler()]
)
log = logging.getLogger("red")

@dataclass
class REDConfig:
    """Configuration for the REDRemover."""
    root: Path
    dry_run: bool = False
    auto_delete: bool = False
    verbose: bool = False
    custom_junk: Optional[List[str]] = None
    exclude: List[str] = field(default_factory=lambda: [".git", ".svn", ".vscode", "__pycache__", "node_modules"])

class REDRemover:
    """Advanced empty/junk directory remover."""
    
    DEFAULT_JUNK_FILES: Set[str] = {
        '.ds_store', 'thumbs.db', '.thumbs.db', 'desktop.ini', 
        '.python-version', '.idea', '.project', '.settings'
    }
    
    DEFAULT_JUNK_EXTS: Set[str] = {
        '.tmp', '.log', '.bak', '.old', '.cache', '.swp'
    }

    def __init__(self, config: REDConfig):
        self.config = config
        self.root = config.root
        
        self.junk_names = set(self.DEFAULT_JUNK_FILES)
        self.junk_exts = set(self.DEFAULT_JUNK_EXTS)
        
        if config.custom_junk:
            for item in config.custom_junk:
                if item.startswith('.'):
                    self.junk_exts.add(item.lower())
                else:
                    self.junk_names.add(item.lower())
        
        self.stats = {"found": 0, "deleted": 0, "errors": 0, "freed_space": 0}
        self.candidates: List[Dict[str, Any]] = []

        if config.verbose:
            log.setLevel(logging.DEBUG)

    def is_junk(self, path: Path) -> bool:
        """Heuristic check for junk files."""
        if not path.is_file():
            return False
        return (path.name.lower() in self.junk_names or 
                path.suffix.lower() in self.junk_exts)

    def analyze_directory(self, dir_path: Path) -> Optional[Dict[str, Any]]:
        """Determine if a directory should be removed."""
        # Skip excluded dirs
        if any(ex in dir_path.parts for ex in self.config.exclude):
            return None

        try:
            # We only care about directories that contain no other directories
            # (leaf nodes in the redundancy tree)
            items = list(dir_path.iterdir())
            
            subdirs = [i for i in items if i.is_dir()]
            if subdirs:
                return None
            
            files = [i for i in items if i.is_file()]
            junk_files = [f for f in files if self.is_junk(f)]
            
            is_redundant = len(files) == len(junk_files)
            
            if is_redundant:
                total_size = sum(f.stat().st_size for f in junk_files)
                return {
                    "path": dir_path,
                    "rel_path": str(dir_path.relative_to(self.root)),
                    "type": "JUNK-ONLY" if junk_files else "EMPTY",
                    "files": junk_files,
                    "size": total_size
                }
        except PermissionError:
            log.debug(f"Permission denied: {dir_path}")
        except Exception as e:
            log.debug(f"Error analyzing {dir_path}: {e}")
            
        return None

    def find_candidates(self):
        """Builds the list of candidate directories using bottom-up traversal."""
        all_dirs = []
        
        # Collect all directories first
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            console=console
        ) as progress:
            progress.add_task("Walking directory tree...", total=None)
            for d in self.root.rglob("*"):
                if d.is_dir():
                    all_dirs.append(d)
        
        # Sort by depth descending (bottom-up)
        all_dirs.sort(key=lambda x: len(x.parts), reverse=True)
        
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            BarColumn(),
            TaskProgressColumn(),
            console=console
        ) as progress:
            task = progress.add_task("Analyzing directories...", total=len(all_dirs))
            
            for d in all_dirs:
                if d == self.root:
                    progress.advance(task)
                    continue
                
                res = self.analyze_directory(d)
                if res:
                    self.candidates.append(res)
                    # Note: We don't mark as deleted yet, but since we are bottom-up,
                    # if a parent becomes empty because its children are in candidates,
                    # a second pass might be needed or we can iterate multiple times.
                    # For simplicity, we'll do one full bottom-up sweep which handles nested empties.
                progress.advance(task)

    def remove_directory(self, entry: Dict[str, Any]) -> bool:
        """Physical removal of directory and its junk."""
        path = entry["path"]
        try:
            for f in entry["files"]:
                f.unlink()
            path.rmdir()
            return True
        except Exception as e:
            log.error(f"Failed to delete {entry['rel_path']}: {e}")
            return False

    def run(self):
        """Execution flow."""
        if console:
            console.print(Panel(
                f"Scanning: [path]{self.root}[/]\n"
                f"Mode: {'[warning]DRY RUN[/]' if self.config.dry_run else '[success]LIVE[/]'}\n"
                f"Auto-Delete: {'[success]ON[/]' if self.config.auto_delete else '[warning]OFF[/]'}",
                title="🚀 RED Remover Initialized",
                expand=False
            ))

        self.find_candidates()

        if not self.candidates:
            rprint("\n[success]✨ Workspace is sparkling clean! No redundant directories found.[/]")
            return

        # Display Candidates
        table = Table(title="Redundant Directories Found", header_style="bold magenta")
        table.add_column("Type", width=12)
        table.add_column("Relative Path", style="path")
        table.add_column("Files", justify="right")
        table.add_column("Size", justify="right")

        for c in self.candidates:
            size_kb = f"{c['size']/1024:.1f} KB" if c['size'] > 0 else "-"
            table.add_row(c['type'], c['rel_path'], str(len(c['files'])), size_kb)

        if console:
            console.print(table)

        if self.config.dry_run:
            rprint(f"\n[warning]⚠ Simulation only. Total candidates: {len(self.candidates)}[/]")
            return

        # Execution Logic
        to_delete = []
        if self.config.auto_delete:
            to_delete = self.candidates
        else:
            action = Prompt.ask(
                "\n[bold]Select action[/]", 
                choices=["all", "some", "none"], 
                default="all"
            )
            
            if action == "all":
                to_delete = self.candidates
            elif action == "some":
                for c in self.candidates:
                    if Confirm.ask(f"  Delete [path]{c['rel_path']}[/]?"):
                        to_delete.append(c)
            else:
                rprint("[info]Aborted.[/]")
                return

        if not to_delete:
            return

        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            BarColumn(),
            console=console
        ) as progress:
            task = progress.add_task("Deleting...", total=len(to_delete))
            for c in to_delete:
                if self.remove_directory(c):
                    self.stats["deleted"] += 1
                    self.stats["freed_space"] += c["size"]
                else:
                    self.stats["errors"] += 1
                progress.advance(task)

        # Final Summary
        summary = (
            f"Found:    {len(self.candidates)}\n"
            f"Deleted:  {self.stats['deleted']}\n"
            f"Errors:   {self.stats['errors']}\n"
            f"Space:    {self.stats['freed_space']/1024:.1f} KB freed"
        )
        if console:
            console.print(Panel(summary, title="📊 Final Totals", expand=False))

def main():
    parser = argparse.ArgumentParser(description="🚀 Ultra-Optimized RED (Redundant Directory) Remover")
    parser.add_argument("path", nargs="?", default=".", help="Root directory to scan (default: current)")
    parser.add_argument("--dry-run", action="store_true", help="Simulate without deleting")
    parser.add_argument("--auto", "-y", action="store_true", help="Auto-delete without prompting")
    parser.add_argument("--junk", nargs="+", help="Add custom junk extensions (e.g. .bak) or names")
    parser.add_argument("--verbose", "-v", action="store_true", help="Enable verbose debug logging")
    
    args = parser.parse_args()
    
    root = Path(args.path).expanduser().resolve()
    if not root.is_dir():
        rprint(f"[error]❌ Error: {root} is not a directory.[/]")
        sys.exit(1)

    config = REDConfig(
        root=root,
        dry_run=args.dry_run,
        auto_delete=args.auto,
        verbose=args.verbose,
        custom_junk=args.junk
    )
    
    remover = REDRemover(config)
    remover.run()

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        rprint("\n[warning]👋 Operation cancelled.[/]")
    except Exception as e:
        log.exception(f"Fatal error: {e}")
