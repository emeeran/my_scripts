#!/bin/bash

# Chained Claude Code CLI Agents Workflow
# Optimization: Added flags, interactive mode, dependency checks, and XML prompting.

set -o pipefail # Fail if any part of a pipe fails

# Defaults
PROJECT_DIR="."
MODEL="claude-3-5-sonnet-20241022" # Updated to a current valid model string, adjust as needed
AUTO_MODE=false
SKIP_TESTS=false

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Usage Help
usage() {
    echo -e "${BLUE}Usage: $0 [OPTIONS]${NC}"
    echo "Options:"
    echo "  -d <dir>    Project directory (default: current)"
    echo "  -m <model>  Claude model to use (default: $MODEL)"
    echo "  -a          Auto mode (skip confirmation prompts - DANGEROUS)"
    echo "  -s          Skip the testing phase"
    echo "  -h          Show this help message"
    exit 1
}

# Parse Arguments
while getopts "d:m:ash" opt; do
  case $opt in
    d) PROJECT_DIR="$OPTARG" ;;
    m) MODEL="$OPTARG" ;;
    a) AUTO_MODE=true ;;
    s) SKIP_TESTS=true ;;
    h) usage ;;
    *) usage ;;
  esac
done

# Setup Logging
LOG_DIR="$PROJECT_DIR/.claude-workflow-logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
mkdir -p "$LOG_DIR"

# --- Functions ---

log_step() {
    echo -e "${GREEN}[$(date +%H:%M:%S)] $1${NC}"
    echo "[$(date +%H:%M:%S)] $1" >> "$LOG_DIR/workflow_${TIMESTAMP}.log"
}

log_warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
    echo "[WARNING] $1" >> "$LOG_DIR/workflow_${TIMESTAMP}.log"
}

error_exit() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
    echo "[ERROR] $1" >> "$LOG_DIR/workflow_${TIMESTAMP}.log"
    exit 1
}

check_dependencies() {
    if ! command -v claude &> /dev/null; then
        error_exit "The 'claude' CLI tool is not installed or not in PATH."
    fi
    if [ -z "$ANTHROPIC_API_KEY" ]; then
        log_warn "ANTHROPIC_API_KEY is not set in the environment. The CLI might fail if not authenticated."
    fi
}

confirm_step() {
    if [ "$AUTO_MODE" = false ]; then
        echo -e "${YELLOW}Proceed to next step? [y/N]${NC}"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_step "Workflow paused or aborted by user."
            exit 0
        fi
    fi
}

# --- Workflow Start ---

check_dependencies

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Claude Code CLI Chained Workflow${NC}"
echo -e "${BLUE}  Model: $MODEL | Dir: $PROJECT_DIR${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Step 1: Code Review
log_step "STEP 1/5: Conducting Code Review..."
PROMPT_REVIEW="<instruction>Perform a comprehensive code review.</instruction>
<focus_areas>
    1. Code quality, consistency, and style
    2. Security vulnerabilities
    3. Potential bugs and edge cases
    4. Architecture and design patterns
</focus_areas>
<output_format>
    Create a detailed report in 'REVIEW_REPORT.md' containing:
    - Critical issues (must fix)
    - Major issues (should fix)
    - Minor improvements (nice to have)
    - For each: File, Line, Description, Recommended Fix.
</output_format>"

claude --model "$MODEL" --directory "$PROJECT_DIR" "$PROMPT_REVIEW" > "$LOG_DIR/01_review_${TIMESTAMP}.log" 2>&1 || error_exit "Code review failed"
log_step "✓ Review complete. Check REVIEW_REPORT.md"
confirm_step

# Step 2: Refactoring
log_step "STEP 2/5: Refactoring Code..."
PROMPT_REFACTOR="<instruction>Refactor code based on REVIEW_REPORT.md.</instruction>
<constraints>
    - Fix Critical and Major issues only.
    - Apply DRY principles.
    - PRESERVE FUNCTIONALITY. Do not break existing logic.
    - Make incremental, safe changes.
</constraints>
<output_format>
    Document changes in 'REFACTOR_CHANGELOG.md' (What, Why, Impact).
</output_format>"

claude --model "$MODEL" --directory "$PROJECT_DIR" "$PROMPT_REFACTOR" > "$LOG_DIR/02_refactor_${TIMESTAMP}.log" 2>&1 || error_exit "Refactoring failed"
log_step "✓ Refactoring complete. Check REFACTOR_CHANGELOG.md"
confirm_step

# Step 3: Performance
log_step "STEP 3/5: Optimizing Performance..."
PROMPT_OPTIMIZE="<instruction>Analyze and optimize for performance.</instruction>
<tasks>
    - Identify bottlenecks (loops, queries, API calls).
    - Implement caching where obvious.
    - Optimize assets/bundles if applicable.
</tasks>
<output_format>
    Create 'PERFORMANCE_REPORT.md' with metrics before/after (estimated) and changes made.
</output_format>"

claude --model "$MODEL" --directory "$PROJECT_DIR" "$PROMPT_OPTIMIZE" > "$LOG_DIR/03_optimize_${TIMESTAMP}.log" 2>&1 || error_exit "Optimization failed"
log_step "✓ Optimization complete. Check PERFORMANCE_REPORT.md"
confirm_step

# Step 4: Documentation
log_step "STEP 4/5: Generating Documentation..."
PROMPT_DOCS="<instruction>Generate project documentation.</instruction>
<tasks>
    1. Update README.md (Overview, Install, Usage).
    2. Add inline docstrings to complex functions.
    3. Create ARCHITECTURE.md (System design, Data flow).
</tasks>"

claude --model "$MODEL" --directory "$PROJECT_DIR" "$PROMPT_DOCS" > "$LOG_DIR/04_documentation_${TIMESTAMP}.log" 2>&1 || error_exit "Documentation failed"
log_step "✓ Documentation complete."

if [ "$SKIP_TESTS" = true ]; then
    log_step "Skipping tests as requested."
else
    confirm_step
    # Step 5: Testing
    log_step "STEP 5/5: Conducting Tests..."
    PROMPT_TEST="<instruction>Implement and run tests.</instruction>
    <tasks>
        1. Create/Update unit tests for core functions.
        2. Ensure >80% coverage target.
        3. Run tests and report results.
    </tasks>
    <output_format>
        Create 'TEST_REPORT.md' with coverage stats and pass/fail summary.
    </output_format>"

    claude --model "$MODEL" --directory "$PROJECT_DIR" "$PROMPT_TEST" > "$LOG_DIR/05_testing_${TIMESTAMP}.log" 2>&1 || error_exit "Testing failed"
    log_step "✓ Testing complete. Check TEST_REPORT.md"
fi

# Final Summary
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  Workflow Completed Successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Logs: $LOG_DIR"
