#!/usr/bin/env python3
"""
AutoKey Phrase Generator Script
Automatically creates AutoKey phrase files with abbreviations and triggers.
"""

import os
import json
from pathlib import Path
from datetime import datetime

# Define all phrases with their abbreviations and expanded text
PHRASES = {
    # Email & Communication
    "eaddr": "your.email@example.com",
    "esig": "Best regards,\nYour Name\nYour Title\nCompany Name",
    "efollow": "Thank you for your email. I will follow up on this shortly.",
    "emeet": "I would like to schedule a meeting to discuss this further.",
    "ethank": "Thank you for reaching out. I appreciate your time.",
    "eapology": "I apologize for any inconvenience this may have caused.",
    "econfirm": "I can confirm that I will be available at the scheduled time.",
    
    # Programming & Development
    "pprint": 'print(f"{}")',
    "pdef": "def function_name():\n    pass",
    "pclass": "class ClassName:\n    def __init__(self):\n        pass",
    "ptry": 'try:\n    pass\nexcept Exception as e:\n    print(f"Error: {e}")',
    "pfor": "for i in range():\n    pass",
    "pif": "if condition:\n    pass",
    "pimport": "import numpy as np\nimport pandas as pd",
    "pcomment": "# TODO: Add implementation here",
    
    # Git Commands
    "gcommit": 'git add . && git commit -m ""',
    "gpush": "git push origin main",
    "gpull": "git pull origin main",
    "gstatus": "git status",
    "gbranch": "git checkout -b feature/",
    "gmerge": "git merge --no-ff",
    "glog": "git log --oneline --graph --all",
    
    # Date & Time (placeholders - customize in AutoKey with scripts)
    "dtoday": datetime.now().strftime("%Y-%m-%d"),
    "dtime": datetime.now().strftime("%H:%M"),
    "dtimestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
    "dweek": datetime.now().strftime("%A"),
    
    # Common Responses
    "tyvm": "Thank you very much!",
    "yw": "You're welcome!",
    "lmk": "Let me know if you need anything else.",
    "fyi": "For your information,",
    "asap": "as soon as possible",
    "eod": "end of day",
    "wfh": "working from home",
    
    # URLs & Links (customize these)
    "ghub": "https://github.com/",
    "gdocs": "https://docs.google.com/",
    "linkedin": "https://www.linkedin.com/in/",
    "website": "https://www.yourwebsite.com",
    
    # File Paths (customize to your system)
    "hdir": "/home/username/",
    "ddir": "/home/username/Documents/",
    "pdir": "/home/username/Projects/",
    "dload": "/home/username/Downloads/",
    
    # Professional Phrases
    "mtg": "meeting",
    "agenda": "Meeting Agenda:\n1. \n2. \n3. ",
    "notes": f"Meeting Notes - {datetime.now().strftime('%Y-%m-%d')}\nAttendees:\nDiscussion:\nAction Items:",
    "actionitem": "[ ] Task - Assigned to: - Due:",
    "deadline": f"Deadline: {datetime.now().strftime('%Y-%m-%d')}",
    "priority": "Priority: High/Medium/Low",
    
    # Documentation
    "readme": "# Project Name\n\n## Description\n\n## Installation\n\n## Usage\n\n## License",
    "docstring": '"""\nFunction description.\n\nArgs:\n    param1: Description\n\nReturns:\n    Description\n"""',
    "license": f"MIT License\n\nCopyright (c) {datetime.now().year} {{your name}}",
}


def get_autokey_data_dir():
    """
    Get the AutoKey data directory path.
    Returns the default location or allows user to specify custom path.
    """
    default_path = Path.home() / ".config" / "autokey" / "data"
    
    if default_path.exists():
        return default_path
    
    # Alternative path for older AutoKey versions
    alt_path = Path.home() / ".local" / "share" / "autokey" / "data"
    if alt_path.exists():
        return alt_path
    
    # If neither exists, create the default one
    default_path.mkdir(parents=True, exist_ok=True)
    return default_path


def create_phrase_file(phrase_dir, abbrev, content, description):
    """
    Create an AutoKey phrase file (.txt) and its metadata (.json).
    
    Args:
        phrase_dir: Directory to store the phrase files
        abbrev: Abbreviation trigger
        content: Expanded text content
        description: Description of the phrase
    """
    # Create phrase text file
    phrase_file = phrase_dir / f"{abbrev}.txt"
    with open(phrase_file, 'w', encoding='utf-8') as f:
        f.write(content)
    
    # Create phrase metadata JSON file
    json_file = phrase_dir / f".{abbrev}.json"
    metadata = {
        "usageCount": 0,
        "omitTrigger": False,
        "prompt": False,
        "description": description,
        "abbreviation": {
            "abbreviations": [abbrev],
            "wordChars": "[\\w]",
            "abbreviations": [abbrev],
            "immediate": False,
            "ignoreCase": False,
            "backspace": True,
            "triggerInside": False
        },
        "hotkey": {
            "hotKey": None,
            "modifiers": []
        },
        "modes": [1],
        "showInTrayMenu": False,
        "matchCase": False,
        "filter": {
            "regex": None,
            "isRecursive": False
        },
        "type": "phrase",
        "sendMode": "kb"
    }
    
    with open(json_file, 'w', encoding='utf-8') as f:
        json.dump(metadata, f, indent=2)
    
    print(f"✓ Created phrase: {abbrev} -> {description}")


def create_folder_metadata(folder_path, folder_name):
    """
    Create the folder metadata file (.folder.json) for AutoKey.
    
    Args:
        folder_path: Path to the folder
        folder_name: Name of the folder
    """
    metadata_file = folder_path / ".folder.json"
    metadata = {
        "type": "folder",
        "title": folder_name,
        "modes": [],
        "usageCount": 0,
        "showInTrayMenu": False,
        "abbreviation": {
            "abbreviations": [],
            "wordChars": "[\\w]",
            "immediate": False,
            "ignoreCase": False,
            "backspace": True,
            "triggerInside": False
        },
        "hotkey": {
            "hotKey": None,
            "modifiers": []
        },
        "filter": {
            "regex": None,
            "isRecursive": False
        }
    }
    
    with open(metadata_file, 'w', encoding='utf-8') as f:
        json.dump(metadata, f, indent=2)


def main():
    """
    Main function to generate all AutoKey phrases.
    """
    print("=" * 60)
    print("AutoKey Phrase Generator")
    print("=" * 60)
    print()
    
    # Get AutoKey data directory
    autokey_dir = get_autokey_data_dir()
    print(f"AutoKey directory: {autokey_dir}")
    
    # Create a folder for productivity phrases
    folder_name = "Productivity Phrases"
    phrase_folder = autokey_dir / folder_name
    phrase_folder.mkdir(exist_ok=True)
    
    # Create folder metadata
    create_folder_metadata(phrase_folder, folder_name)
    print(f"✓ Created folder: {folder_name}")
    print()
    
    # Create each phrase
    print("Creating phrases...")
    print("-" * 60)
    
    for abbrev, content in PHRASES.items():
        # Generate a description based on the abbreviation
        if abbrev.startswith('e'):
            category = "Email"
        elif abbrev.startswith('p'):
            category = "Programming"
        elif abbrev.startswith('g'):
            category = "Git"
        elif abbrev.startswith('d'):
            category = "Date/Time"
        elif abbrev == 'tyvm' or abbrev == 'yw' or abbrev == 'lmk' or abbrev == 'fyi' or abbrev == 'asap' or abbrev == 'eod' or abbrev == 'wfh':
            category = "Common Response"
        elif 'hub' in abbrev or 'docs' in abbrev or 'linkedin' in abbrev or 'website' in abbrev:
            category = "URL"
        elif 'dir' in abbrev or 'dload' in abbrev:
            category = "File Path"
        elif abbrev in ['mtg', 'agenda', 'notes', 'actionitem', 'deadline', 'priority']:
            category = "Professional"
        else:
            category = "Documentation"
        
        description = f"{category}: {abbrev}"
        create_phrase_file(phrase_folder, abbrev, content, description)
    
    print("-" * 60)
    print()
    print("=" * 60)
    print(f"✓ Successfully created {len(PHRASES)} phrases!")
    print("=" * 60)
    print()
    print("NEXT STEPS:")
    print("1. Restart AutoKey or reload configuration")
    print("2. Open AutoKey and verify the phrases appear")
    print("3. Customize the phrases to match your needs")
    print("4. Test by typing an abbreviation + space (e.g., 'eaddr ')")
    print()
    print("TIPS:")
    print("- Edit phrases in AutoKey GUI for easier customization")
    print("- Change trigger settings in phrase properties")
    print("- Backup your AutoKey folder regularly")
    print()
    print(f"Phrases location: {phrase_folder}")
    print("=" * 60)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"Error: {e}")
        print("\nIf AutoKey directory doesn't exist, please:")
        print("1. Install AutoKey: sudo apt install autokey-gtk (or autokey-qt)")
        print("2. Run AutoKey at least once to create the config directory")
        print("3. Run this script again")
