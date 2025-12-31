#!/bin/bash

# Chained Claude Code CLI Agents Workflow
# Purpose: Automated code review, refactor, optimize, document, and test workflow

set -e  # Exit on error

# Configuration
PROJECT_DIR="${1:-.}"
LOG_DIR="$PROJECT_DIR/.claude-workflow-logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
MODEL="claude-sonnet-4-5-20250929"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Create log directory
mkdir -p "$LOG_DIR"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Claude Code CLI Chained Workflow${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Function to log and display messages
log_step() {
    echo -e "${GREEN}[$(date +%H:%M:%S)] $1${NC}"
    echo "[$(date +%H:%M:%S)] $1" >> "$LOG_DIR/workflow_${TIMESTAMP}.log"
}

error_exit() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
    echo "[ERROR] $1" >> "$LOG_DIR/workflow_${TIMESTAMP}.log"
    exit 1
}

# Step 1: Code Review
log_step "STEP 1/5: Conducting Code Review..."
claude --model "$MODEL" \
    --directory "$PROJECT_DIR" \
    "Perform a comprehensive code review of this project. Focus on:
    1. Code quality and best practices
    2. Security vulnerabilities
    3. Potential bugs and edge cases
    4. Architecture and design patterns
    5. Code consistency and style
    
    Create a detailed report in REVIEW_REPORT.md with:
    - Critical issues (must fix)
    - Major issues (should fix)
    - Minor improvements (nice to have)
    - Positive observations
    
    For each issue, include:
    - File and line number
    - Description
    - Recommended fix
    - Priority level" \
    > "$LOG_DIR/01_review_${TIMESTAMP}.log" 2>&1 || error_exit "Code review failed"

log_step "✓ Code review completed. Check REVIEW_REPORT.md"

# Step 2: Refactoring
log_step "STEP 2/5: Refactoring Code..."
claude --model "$MODEL" \
    --directory "$PROJECT_DIR" \
    "Based on the code review in REVIEW_REPORT.md, refactor the code:
    1. Fix all critical and major issues identified
    2. Improve code structure and modularity
    3. Apply DRY (Don't Repeat Yourself) principle
    4. Enhance error handling
    5. Improve naming conventions
    6. Remove dead code
    
    Document all changes made in REFACTOR_CHANGELOG.md with:
    - What was changed
    - Why it was changed
    - Impact of the change
    
    Make incremental, safe changes and preserve functionality." \
    > "$LOG_DIR/02_refactor_${TIMESTAMP}.log" 2>&1 || error_exit "Refactoring failed"

log_step "✓ Refactoring completed. Check REFACTOR_CHANGELOG.md"

# Step 3: Performance Optimization
log_step "STEP 3/5: Optimizing Performance..."
claude --model "$MODEL" \
    --directory "$PROJECT_DIR" \
    "Optimize the application for performance:
    1. Identify and fix performance bottlenecks
    2. Optimize database queries and indexing
    3. Implement caching strategies
    4. Optimize API calls and network requests
    5. Reduce bundle size (if frontend)
    6. Implement lazy loading where appropriate
    7. Optimize images and assets
    8. Profile memory usage and fix leaks
    
    Create PERFORMANCE_REPORT.md documenting:
    - Performance metrics before/after
    - Optimizations implemented
    - Recommended tools for monitoring
    - Future optimization opportunities" \
    > "$LOG_DIR/03_optimize_${TIMESTAMP}.log" 2>&1 || error_exit "Optimization failed"

log_step "✓ Performance optimization completed. Check PERFORMANCE_REPORT.md"

# Step 4: Documentation
log_step "STEP 4/5: Generating Documentation..."
claude --model "$MODEL" \
    --directory "$PROJECT_DIR" \
    "Create comprehensive documentation:
    1. Update/create README.md with:
       - Project overview
       - Installation instructions
       - Usage examples
       - Configuration guide
       - Troubleshooting
    
    2. Add inline code documentation:
       - Function/method docstrings
       - Complex logic explanations
       - API endpoint documentation
    
    3. Create ARCHITECTURE.md explaining:
       - System architecture
       - Component relationships
       - Data flow
       - Design decisions
    
    4. Create API_DOCUMENTATION.md (if applicable):
       - Endpoint descriptions
       - Request/response formats
       - Authentication
       - Error codes
    
    5. Update CONTRIBUTING.md with:
       - Code style guide
       - Git workflow
       - Testing requirements
       - Pull request process" \
    > "$LOG_DIR/04_documentation_${TIMESTAMP}.log" 2>&1 || error_exit "Documentation failed"

log_step "✓ Documentation completed"

# Step 5: Testing
log_step "STEP 5/5: Conducting Tests..."
claude --model "$MODEL" \
    --directory "$PROJECT_DIR" \
    "Implement and run comprehensive tests:
    1. Create/update unit tests for all functions/methods
    2. Create/update integration tests for API endpoints
    3. Add edge case and error handling tests
    4. Implement end-to-end tests for critical workflows
    5. Add performance/load tests
    6. Ensure test coverage >80%
    
    Run all tests and create TEST_REPORT.md with:
    - Test coverage statistics
    - Test results summary
    - Failed tests (if any) with details
    - Recommendations for additional tests
    
    Also create test documentation explaining:
    - How to run tests
    - Test structure and organization
    - Mocking and fixtures used
    - Continuous integration setup" \
    > "$LOG_DIR/05_testing_${TIMESTAMP}.log" 2>&1 || error_exit "Testing failed"

log_step "✓ Testing completed. Check TEST_REPORT.md"

# Final Summary
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  Workflow Completed Successfully!${NC}"
echo -e "${GREEN}========================================${NC}\n"

echo -e "${YELLOW}Generated Files:${NC}"
echo "  📋 REVIEW_REPORT.md - Code review findings"
echo "  🔄 REFACTOR_CHANGELOG.md - Refactoring changes"
echo "  ⚡ PERFORMANCE_REPORT.md - Performance optimizations"
echo "  📚 README.md - Project documentation"
echo "  🏗️  ARCHITECTURE.md - System architecture"
echo "  📡 API_DOCUMENTATION.md - API docs (if applicable)"
echo "  🤝 CONTRIBUTING.md - Contribution guidelines"
echo "  ✅ TEST_REPORT.md - Test results and coverage"

echo -e "\n${YELLOW}Log Files:${NC}"
echo "  All logs saved in: $LOG_DIR/"

echo -e "\n${BLUE}Next Steps:${NC}"
echo "  1. Review all generated reports"
echo "  2. Test the application thoroughly"
echo "  3. Commit changes with detailed commit messages"
echo "  4. Deploy to staging for validation"

echo -e "\n${GREEN}Happy Coding! 🚀${NC}\n"
