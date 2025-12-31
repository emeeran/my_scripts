#!/bin/bash

# Obsidian Vault Structure Creator
# This script creates a complete directory structure for an Obsidian vault
# with organized folders and template files

set -e  # Exit on any error

# Function to print colored output
print_status() {
    echo -e "\033[32m[INFO]\033[0m $1"
}

print_error() {
    echo -e "\033[31m[ERROR]\033[0m $1"
}

print_success() {
    echo -e "\033[32m[SUCCESS]\033[0m $1"
}

# Function to create directory and log
create_dir() {
    local dir_path="$1"
    if mkdir -p "$dir_path"; then
        print_status "Created directory: $dir_path"
    else
        print_error "Failed to create directory: $dir_path"
        exit 1
    fi
}

# Function to create file with content
create_file() {
    local file_path="$1"
    local content="$2"
    
    if echo "$content" > "$file_path"; then
        print_status "Created file: $file_path"
    else
        print_error "Failed to create file: $file_path"
        exit 1
    fi
}

# Main vault directory
VAULT_NAME="Obsidian Vault"

# Check if vault already exists
if [ -d "$VAULT_NAME" ]; then
    echo -e "\033[33m[WARNING]\033[0m Directory '$VAULT_NAME' already exists."
    read -p "Do you want to continue? This may overwrite existing files. (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation cancelled."
        exit 0
    fi
fi

print_status "Creating Obsidian Vault structure..."

# Create main vault directory
create_dir "$VAULT_NAME"

# Create main directories with emojis
create_dir "$VAULT_NAME/📥 Inbox"
create_dir "$VAULT_NAME/📥 Inbox/Fleeting Notes"
create_dir "$VAULT_NAME/🗂️ Areas"
create_dir "$VAULT_NAME/🗂️ Areas/Personal"
create_dir "$VAULT_NAME/🗂️ Areas/Professional"
create_dir "$VAULT_NAME/🗂️ Areas/Learning"
create_dir "$VAULT_NAME/🔬 Projects"
create_dir "$VAULT_NAME/🔬 Projects/Active Projects"
create_dir "$VAULT_NAME/🔬 Projects/Completed Projects"
create_dir "$VAULT_NAME/🧠 Knowledge Base"
create_dir "$VAULT_NAME/🧠 Knowledge Base/Concepts"
create_dir "$VAULT_NAME/🧠 Knowledge Base/Definitions"
create_dir "$VAULT_NAME/🧠 Knowledge Base/Resources"
create_dir "$VAULT_NAME/📅 Journal"
create_dir "$VAULT_NAME/📅 Journal/Daily Notes"
create_dir "$VAULT_NAME/📅 Journal/Weekly Reviews"
create_dir "$VAULT_NAME/📅 Journal/Monthly Reflections"
create_dir "$VAULT_NAME/🔖 Templates"

# Create initial files
print_status "Creating initial files..."

# Inbox.md
create_file "$VAULT_NAME/📥 Inbox/Inbox.md" "# Inbox

## Quick Capture
- Add new ideas, tasks, and notes here
- Process regularly and move to appropriate folders

## Today's Captures
- 

## To Process
- 

---
*Last updated: $(date '+%Y-%m-%d %H:%M')*"

# Template files
create_file "$VAULT_NAME/🔖 Templates/Daily Note Template.md" "# {{date:YYYY-MM-DD}} - {{date:dddd}}

## 📅 Today's Focus
- 

## ✅ Tasks
- [ ] 
- [ ] 
- [ ] 

## 📝 Notes
- 

## 🎯 Key Accomplishments
- 

## 🔄 Tomorrow's Priorities
- 

## 💭 Reflections
- 

---
**Weather:** 
**Mood:** 
**Energy Level:** /10

[[{{date:YYYY-MM-DD|offset:-1d}}]] ← Previous Day | Next Day → [[{{date:YYYY-MM-DD|offset:1d}}]]"

create_file "$VAULT_NAME/🔖 Templates/Project Template.md" "# {{title}}

## 📋 Project Overview
**Status:** 
**Priority:** 
**Start Date:** 
**Target Completion:** 
**Stakeholders:** 

## 🎯 Objectives
- 

## 📊 Key Metrics/Success Criteria
- 

## 📋 Tasks
- [ ] 
- [ ] 
- [ ] 

## 📚 Resources
- 

## 🗒️ Notes
- 

## 🔄 Updates
### {{date:YYYY-MM-DD}}
- 

## 🎉 Completion Notes
- 

---
**Tags:** #project 
**Related:** "

create_file "$VAULT_NAME/🔖 Templates/Meeting Notes Template.md" "# {{title}} - {{date:YYYY-MM-DD}}

## 📅 Meeting Details
**Date:** {{date:YYYY-MM-DD}}
**Time:** 
**Duration:** 
**Attendees:** 
**Meeting Type:** 

## 🎯 Agenda
- 

## 📝 Key Discussion Points
- 

## ✅ Decisions Made
- 

## 🎯 Action Items
- [ ] **@Person** - Task description - Due: 
- [ ] **@Person** - Task description - Due: 

## 📋 Follow-up Items
- 

## 📚 Resources/Links
- 

## 🗒️ Additional Notes
- 

---
**Next Meeting:** 
**Tags:** #meeting 
**Related:** "

# Create README for the vault
create_file "$VAULT_NAME/README.md" "# Obsidian Vault

This vault is organized using the PARA method with additional structure for journaling and templates.

## 📁 Folder Structure

### 📥 Inbox
- **Purpose:** Capture new ideas, tasks, and notes
- **Workflow:** Process regularly and move items to appropriate folders
- **Files:** Quick notes, fleeting thoughts, temporary items

### 🗂️ Areas
- **Personal:** Personal projects, habits, and ongoing responsibilities
- **Professional:** Work-related ongoing responsibilities and areas of focus
- **Learning:** Educational content, courses, and skill development

### 🔬 Projects
- **Active Projects:** Current projects with defined outcomes and deadlines
- **Completed Projects:** Archived completed projects for reference

### 🧠 Knowledge Base
- **Concepts:** Core ideas and theoretical knowledge
- **Definitions:** Terms, acronyms, and definitions
- **Resources:** Reference materials, links, and tools

### 📅 Journal
- **Daily Notes:** Daily reflections and planning
- **Weekly Reviews:** Weekly planning and review sessions
- **Monthly Reflections:** Monthly goal setting and reflection

### 🔖 Templates
- Standardized templates for consistent note-taking
- Templates for projects, meetings, and daily notes

## 🔄 Workflow Tips

1. **Capture** everything in the Inbox first
2. **Process** the Inbox regularly (daily/weekly)
3. **Organize** notes into appropriate Areas or Projects
4. **Review** and update regularly
5. **Archive** completed projects

## 🏷️ Recommended Tags

- #project - For project-related notes
- #meeting - For meeting notes
- #idea - For new ideas and brainstorming
- #review - For weekly/monthly reviews
- #learning - For educational content
- #reference - For reference materials

---
*Created: $(date '+%Y-%m-%d %H:%M')*"

# Create a .gitignore file for the vault
create_file "$VAULT_NAME/.gitignore" "# Obsidian
.obsidian/
.obsidian/*

# System files
.DS_Store
Thumbs.db

# Temporary files
*.tmp
*.temp
~*

# Backup files
*.bak
*.backup"

print_success "Obsidian Vault structure created successfully!"
print_status "Location: $(pwd)/$VAULT_NAME"

echo
echo "📁 Directory structure created:"
echo "├── 📥 Inbox/"
echo "│   ├── Fleeting Notes/"
echo "│   └── Inbox.md"
echo "├── 🗂️ Areas/"
echo "│   ├── Personal/"
echo "│   ├── Professional/"
echo "│   └── Learning/"
echo "├── 🔬 Projects/"
echo "│   ├── Active Projects/"
echo "│   └── Completed Projects/"
echo "├── 🧠 Knowledge Base/"
echo "│   ├── Concepts/"
echo "│   ├── Definitions/"
echo "│   └── Resources/"
echo "├── 📅 Journal/"
echo "│   ├── Daily Notes/"
echo "│   ├── Weekly Reviews/"
echo "│   └── Monthly Reflections/"
echo "└── 🔖 Templates/"
echo "    ├── Daily Note Template.md"
echo "    ├── Project Template.md"
echo "    └── Meeting Notes Template.md"
echo
echo "🎉 Your Obsidian vault is ready to use!"
echo "💡 Open the vault in Obsidian and start organizing your knowledge!"
