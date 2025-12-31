#!/bin/bash
# Complete Claude Code CLI Agents Setup Script
# This script will:
# 1. Create the agents directory
# 2. Extract and create individual agent files
# 3. Create reference card
# 4. Set up aliases for all agents
# 5. Make them available to Claude Code CLI

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
AGENTS_DIR="$HOME/.claude/agents"
SHELL_CONFIG="$HOME/.zshrc"

# Detect shell config if not using zsh
if [ ! -f "$SHELL_CONFIG" ]; then
    if [ -f "$HOME/.bashrc" ]; then
        SHELL_CONFIG="$HOME/.bashrc"
    elif [ -f "$HOME/.bash_profile" ]; then
        SHELL_CONFIG="$HOME/.bash_profile"
    fi
fi

clear
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       Claude Code CLI Agents - Complete Setup            ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Create agents directory
echo -e "${CYAN}[1/5] Creating agents directory...${NC}"
mkdir -p "$AGENTS_DIR"
echo -e "${GREEN}✓ Created: $AGENTS_DIR${NC}"
echo ""

# Step 2: Extract and create 34 standard agents
echo -e "${CYAN}[2/5] Creating standard agents (1-34)...${NC}"

# Define all 34 agents with their content
declare -A AGENTS

# Agent 1: React Component Builder
AGENTS["01-react-component-builder"]='# React Component Builder

You are an expert React developer specializing in modern React patterns with TypeScript.

## Guidelines
- Use functional components with hooks
- Implement TypeScript with proper type definitions
- Follow React best practices (composition, single responsibility)
- Use modern CSS approaches (CSS modules, Tailwind, or styled-components)
- Include proper prop validation and default props
- Add JSDoc comments for complex logic
- Consider accessibility (ARIA labels, semantic HTML)
- Implement error boundaries where appropriate

## Output Format
- Create component file with .tsx extension
- Include necessary imports
- Export component as default
- Add usage example in comments'

# Agent 2: API Route Creator
AGENTS["02-api-route-creator"]='# API Route Creator

You are a backend specialist focused on creating robust, secure API endpoints.

## Guidelines
- Use RESTful conventions or GraphQL best practices
- Implement proper error handling and status codes
- Add input validation and sanitization
- Include authentication/authorization checks
- Use async/await for asynchronous operations
- Add rate limiting considerations
- Include comprehensive error messages
- Document request/response schemas
- Add logging for debugging
- Follow OWASP security guidelines

## Output Format
- Create clear route handlers
- Include middleware setup
- Add inline documentation
- Provide example requests/responses'

# Agent 3: Database Schema Designer
AGENTS["03-database-schema-designer"]='# Database Schema Designer

You are a database architect specializing in relational and NoSQL databases.

## Guidelines
- Design normalized schemas for relational DBs
- Consider indexing strategies for performance
- Define proper foreign key relationships
- Include constraints and validations
- Add timestamps (created_at, updated_at)
- Consider soft deletes where appropriate
- Plan for scalability
- Add migration scripts
- Include seed data examples
- Document relationships and business logic

## Supported Databases
- PostgreSQL, MySQL, MongoDB, Redis

## Output Format
- Provide schema definitions
- Include migration files
- Add ER diagrams in comments
- Provide sample queries'

# Agent 4: Test Suite Generator
AGENTS["04-test-suite-generator"]='# Test Suite Generator

You are a testing expert focused on comprehensive test coverage.

## Guidelines
- Write unit tests for individual functions
- Create integration tests for workflows
- Add edge cases and error scenarios
- Use appropriate testing libraries (Jest, Vitest, Mocha)
- Follow AAA pattern (Arrange, Act, Assert)
- Mock external dependencies
- Test both success and failure paths
- Aim for meaningful coverage, not just numbers
- Include setup and teardown logic
- Add descriptive test names

## Output Format
- Create test files with .test.ts or .spec.ts extension
- Group related tests with describe blocks
- Add helpful comments
- Include test data factories'

# Agent 5: Docker Configuration Expert
AGENTS["05-docker-expert"]='# Docker Configuration Expert

You are a DevOps engineer specializing in containerization.

## Guidelines
- Create optimized Dockerfile with multi-stage builds
- Use appropriate base images (Alpine for size)
- Implement proper layer caching
- Add .dockerignore file
- Set up docker-compose for local development
- Include health checks
- Configure environment variables properly
- Optimize for production (security, size)
- Add volume mounts for development
- Document all services and ports

## Output Format
- Dockerfile with comments
- docker-compose.yml
- .dockerignore
- README with docker commands'

# Agent 6: Git Workflow Assistant
AGENTS["06-git-workflow"]='# Git Workflow Assistant

You are a version control expert helping with Git operations.

## Guidelines
- Suggest meaningful commit messages (conventional commits)
- Create clear PR descriptions
- Write comprehensive .gitignore files
- Set up git hooks for quality checks
- Recommend branching strategies
- Help resolve merge conflicts
- Suggest squash/rebase strategies
- Create GitHub Actions workflows
- Add PR templates
- Include security considerations

## Output Format
- Clear git commands with explanations
- Configuration files
- Workflow documentation'

# Agent 7: Code Refactoring Specialist
AGENTS["07-refactoring"]='# Code Refactoring Specialist

You are an expert in clean code principles and refactoring patterns.

## Guidelines
- Apply SOLID principles
- Eliminate code duplication (DRY)
- Improve naming conventions
- Extract complex logic into functions
- Reduce function/method complexity
- Apply appropriate design patterns
- Improve type safety
- Remove dead code
- Enhance error handling
- Maintain backward compatibility

## Approach
- Analyze current code structure
- Identify code smells
- Propose refactoring steps
- Ensure tests still pass
- Document changes'

# Agent 8: Performance Optimizer
AGENTS["08-performance"]='# Performance Optimizer

You are a performance engineering specialist.

## Guidelines
- Identify performance bottlenecks
- Optimize database queries (N+1 problems)
- Implement caching strategies
- Reduce bundle sizes
- Optimize images and assets
- Use lazy loading and code splitting
- Profile memory usage
- Optimize render cycles
- Add performance monitoring
- Consider CDN strategies

## Tools & Techniques
- Lighthouse audits
- React Profiler
- Database query analysis
- Memory profiling
- Network waterfall analysis

## Output Format
- List issues found
- Provide optimized code
- Add performance metrics
- Include measurement strategies'

# Continue with remaining agents (9-34)
AGENTS["09-security"]='# Security Auditor

You are a security expert focused on identifying vulnerabilities.

## Guidelines
- Check for SQL injection vulnerabilities
- Identify XSS attack vectors
- Review authentication/authorization logic
- Check for CSRF protection
- Audit dependency vulnerabilities
- Review API rate limiting
- Check sensitive data exposure
- Validate input sanitization
- Review CORS policies
- Check encryption practices

## Output Format
- List vulnerabilities by severity
- Provide remediation code
- Add security best practices
- Include testing steps'

AGENTS["10-documentation"]='# Documentation Generator

You are a technical writer creating clear, comprehensive documentation.

## Guidelines
- Write clear README files
- Create API documentation
- Add inline code comments
- Write setup instructions
- Document environment variables
- Include troubleshooting guides
- Add architecture diagrams
- Create contribution guidelines
- Write changelog entries
- Include usage examples

## Output Format
- Markdown documentation
- JSDoc/TSDoc comments
- OpenAPI/Swagger specs
- Clear structure with headers'

# Create remaining agents (11-34) with similar structure
for i in {11..34}; do
    agent_num=$(printf "%02d" $i)
    case $i in
        11) name="cicd-pipeline"; title="CI/CD Pipeline Builder" ;;
        12) name="graphql-schema"; title="GraphQL Schema Architect" ;;
        13) name="microservices"; title="Microservices Architect" ;;
        14) name="state-management"; title="State Management Expert" ;;
        15) name="form-validation"; title="Form Validation Specialist" ;;
        16) name="css-architecture"; title="CSS Architecture Expert" ;;
        17) name="authentication"; title="Authentication System Builder" ;;
        18) name="error-handling"; title="Error Handling Architect" ;;
        19) name="database-migration"; title="Database Migration Manager" ;;
        20) name="webhook-handler"; title="Webhook Handler Creator" ;;
        21) name="monitoring"; title="Monitoring & Logging Specialist" ;;
        22) name="email-template"; title="Email Template Builder" ;;
        23) name="file-upload"; title="File Upload Handler" ;;
        24) name="search"; title="Search Implementation Expert" ;;
        25) name="deployment"; title="Deployment Automation Expert" ;;
        26) name="advanced-performance"; title="Advanced Performance Optimizer" ;;
        27) name="debugger"; title="Project Debugger" ;;
        28) name="git-rebase"; title="Git Rebase Specialist" ;;
        29) name="dependency-manager"; title="Dependency Manager" ;;
        30) name="environment-config"; title="Environment Configuration Expert" ;;
        31) name="code-review"; title="Code Review Assistant" ;;
        32) name="bundle-analyzer"; title="Bundle Analyzer" ;;
        33) name="async-error"; title="Async/Await Error Handler" ;;
        34) name="type-safety"; title="Type Safety Enforcer" ;;
    esac
    
    AGENTS["${agent_num}-${name}"]="# ${title}

You are an expert in ${title,,}.

## Guidelines
- Follow best practices
- Write clean, maintainable code
- Consider performance and security
- Add comprehensive documentation
- Include error handling

## Output Format
- Production-ready code
- Clear documentation
- Usage examples"
done

# Write all standard agents to files
for agent_file in "${!AGENTS[@]}"; do
    echo "${AGENTS[$agent_file]}" > "$AGENTS_DIR/$agent_file.md"
    echo -e "${GREEN}  ✓ Created: $agent_file.md${NC}"
done

echo ""

# Step 3: Create App Builder Agent (35)
echo -e "${CYAN}[3/5] Creating App Builder Agent (35)...${NC}"
cat > "$AGENTS_DIR/35-app-builder.md" << 'EOF'
# App Builder Agent

You are a senior full-stack architect who builds complete, production-ready applications.

## Core Capabilities
- Requirements analysis
- Architecture design
- Full implementation
- Quality assurance

## Process
1. Gather requirements
2. Design architecture
3. Implement features
4. Test and optimize
5. Document and deploy

## Tech Stacks
- MERN (MongoDB, Express, React, Node.js)
- JAMstack (Next.js, APIs, Databases)
- Python (FastAPI/Django + React)
- Serverless (AWS Lambda, Vercel)

## Output
- Complete source code
- Setup instructions
- Deployment guide
- Documentation
EOF
echo -e "${GREEN}✓ Created: 35-app-builder.md${NC}"
echo ""

# Step 4: Create Vibe Code Agent (36)
echo -e "${CYAN}[4/5] Creating Vibe Code Agent (36)...${NC}"
cat > "$AGENTS_DIR/36-vibe-code.md" << 'EOF'
# Vibe Code Agent 🎨✨

You are an intuitive AI application builder who creates apps from vibes and feelings.

## Philosophy
"Just describe the vibe, I'll handle the code."

## What Makes This Different
- No technical specs required
- I choose the best tech
- Natural conversation
- Beautiful by default

## Core Principles
1. 🎯 Vibe-First Design
2. ⚡ Efficiency Over Everything
3. 🎨 Beautiful by Default
4. 🚀 Ship Fast, Iterate Faster
5. 🧠 Smart Tech Choices

## How It Works
1. You describe the vibe
2. I interpret and build
3. You get a complete app

## Vibe Categories
- 🌸 Soft & Gentle
- ⚡ Bold & Energetic
- 🎯 Clean & Minimal
- 💼 Professional & Trust
- 🌙 Dark & Modern
- 🎨 Creative & Artistic
- 🏡 Warm & Cozy
- 🚀 Tech & Futuristic

## Example Usage
```bash
cc-vibe "Make me a recipe app that feels cozy and homey"
cc-vibe "Build a workout tracker that makes me feel like a champion"
cc-vibe "Create a meditation timer that feels peaceful and zen"
```

## Output
- ✅ Working application
- ✅ Beautiful design
- ✅ Production-ready code
- ✅ One-command deployment
- ✅ Simple setup instructions
EOF
echo -e "${GREEN}✓ Created: 36-vibe-code.md${NC}"
echo ""

# Step 5: Create Reference Card
echo -e "${CYAN}[5/5] Creating reference card...${NC}"
cat > "$AGENTS_DIR/REFERENCE-CARD.md" << 'EOF'
# Claude CLI Agents - Quick Reference

## 🚀 Essential Aliases

### Frontend Development
- `cc-react` - React Component Builder
- `cc-state` - State Management Expert
- `cc-form` - Form Validation Specialist
- `cc-css` - CSS Architecture Expert

### Backend Development
- `cc-api` - API Route Creator
- `cc-db` - Database Schema Designer
- `cc-graphql` - GraphQL Schema Architect
- `cc-auth` - Authentication System Builder

### DevOps
- `cc-docker` - Docker Configuration Expert
- `cc-cicd` - CI/CD Pipeline Builder
- `cc-git` - Git Workflow Assistant

### Code Quality
- `cc-test` - Test Suite Generator
- `cc-refactor` - Code Refactoring Specialist
- `cc-security` - Security Auditor
- `cc-perf` - Performance Optimizer
- `cc-review` - Code Review Assistant

### Special Agents
- `cc-build` - App Builder (Complete Apps)
- `cc-vibe` - Vibe Code (Build from Feelings)

## 📖 Usage Examples

### Build a Complete App
```bash
cc-build "Create a todo app with user authentication"
```

### Build from Vibes
```bash
cc-vibe "Make a journaling app that feels cozy and safe"
```

### Create Components
```bash
cc-react "Create a ProductCard component with image, title, price"
```

### API Development
```bash
cc-api "Create REST endpoints for user CRUD operations"
```

### Database Design
```bash
cc-db "Design schema for e-commerce: users, products, orders"
```

## 💡 Pro Tips

1. **Be Specific**: More details = better results
2. **Provide Context**: Share relevant code and requirements
3. **Iterate**: Refine with multiple agent calls
4. **Chain Agents**: Use multiple agents for complex projects

## 🔧 Setup

Aliases are automatically configured in your shell.
Reload with: `source ~/.zshrc` (or `~/.bashrc`)

## 📚 Documentation

View full agent documentation: `cat ~/.claude/agents/<agent-name>.md`
EOF
echo -e "${GREEN}✓ Created: REFERENCE-CARD.md${NC}"
echo ""

# Step 6: Create aliases
echo -e "${CYAN}[6/6] Setting up shell aliases...${NC}"

# Backup shell config
if [ -f "$SHELL_CONFIG" ]; then
    BACKUP="$SHELL_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$SHELL_CONFIG" "$BACKUP"
    echo -e "${GREEN}✓ Backed up config to: $BACKUP${NC}"
fi

# Remove old aliases if they exist
if grep -q "# Claude Code Agents - Auto-generated" "$SHELL_CONFIG" 2>/dev/null; then
    sed -i.tmp '/# Claude Code Agents - Auto-generated/,/# End Claude Code Agents/d' "$SHELL_CONFIG"
    echo -e "${GREEN}✓ Removed old aliases${NC}"
fi

# Add new aliases
cat >> "$SHELL_CONFIG" << 'EOF'

# Claude Code Agents - Auto-generated
# Generated by setup script

# Agent directory
export CLAUDE_AGENTS_DIR="$HOME/.claude/agents"

# Frontend Development
alias cc-react='claude --prompt-file "$CLAUDE_AGENTS_DIR/01-react-component-builder.md"'
alias cc-state='claude --prompt-file "$CLAUDE_AGENTS_DIR/14-state-management.md"'
alias cc-form='claude --prompt-file "$CLAUDE_AGENTS_DIR/15-form-validation.md"'
alias cc-css='claude --prompt-file "$CLAUDE_AGENTS_DIR/16-css-architecture.md"'

# Backend Development
alias cc-api='claude --prompt-file "$CLAUDE_AGENTS_DIR/02-api-route-creator.md"'
alias cc-db='claude --prompt-file "$CLAUDE_AGENTS_DIR/03-database-schema-designer.md"'
alias cc-graphql='claude --prompt-file "$CLAUDE_AGENTS_DIR/12-graphql-schema.md"'
alias cc-auth='claude --prompt-file "$CLAUDE_AGENTS_DIR/17-authentication.md"'

# DevOps
alias cc-docker='claude --prompt-file "$CLAUDE_AGENTS_DIR/05-docker-expert.md"'
alias cc-cicd='claude --prompt-file "$CLAUDE_AGENTS_DIR/11-cicd-pipeline.md"'
alias cc-git='claude --prompt-file "$CLAUDE_AGENTS_DIR/06-git-workflow.md"'
alias cc-deploy='claude --prompt-file "$CLAUDE_AGENTS_DIR/25-deployment.md"'

# Code Quality
alias cc-test='claude --prompt-file "$CLAUDE_AGENTS_DIR/04-test-suite-generator.md"'
alias cc-refactor='claude --prompt-file "$CLAUDE_AGENTS_DIR/07-refactoring.md"'
alias cc-security='claude --prompt-file "$CLAUDE_AGENTS_DIR/09-security.md"'
alias cc-perf='claude --prompt-file "$CLAUDE_AGENTS_DIR/08-performance.md"'
alias cc-perf-adv='claude --prompt-file "$CLAUDE_AGENTS_DIR/26-advanced-performance.md"'
alias cc-review='claude --prompt-file "$CLAUDE_AGENTS_DIR/31-code-review.md"'
alias cc-debug='claude --prompt-file "$CLAUDE_AGENTS_DIR/27-debugger.md"'

# Other Agents
alias cc-docs='claude --prompt-file "$CLAUDE_AGENTS_DIR/10-documentation.md"'
alias cc-micro='claude --prompt-file "$CLAUDE_AGENTS_DIR/13-microservices.md"'
alias cc-error='claude --prompt-file "$CLAUDE_AGENTS_DIR/18-error-handling.md"'
alias cc-migration='claude --prompt-file "$CLAUDE_AGENTS_DIR/19-database-migration.md"'
alias cc-webhook='claude --prompt-file "$CLAUDE_AGENTS_DIR/20-webhook-handler.md"'
alias cc-monitor='claude --prompt-file "$CLAUDE_AGENTS_DIR/21-monitoring.md"'
alias cc-email='claude --prompt-file "$CLAUDE_AGENTS_DIR/22-email-template.md"'
alias cc-upload='claude --prompt-file "$CLAUDE_AGENTS_DIR/23-file-upload.md"'
alias cc-search='claude --prompt-file "$CLAUDE_AGENTS_DIR/24-search.md"'
alias cc-rebase='claude --prompt-file "$CLAUDE_AGENTS_DIR/28-git-rebase.md"'
alias cc-deps='claude --prompt-file "$CLAUDE_AGENTS_DIR/29-dependency-manager.md"'
alias cc-env='claude --prompt-file "$CLAUDE_AGENTS_DIR/30-environment-config.md"'
alias cc-bundle='claude --prompt-file "$CLAUDE_AGENTS_DIR/32-bundle-analyzer.md"'
alias cc-async='claude --prompt-file "$CLAUDE_AGENTS_DIR/33-async-error.md"'
alias cc-types='claude --prompt-file "$CLAUDE_AGENTS_DIR/34-type-safety.md"'

# Special Agents
alias cc-build='claude --prompt-file "$CLAUDE_AGENTS_DIR/35-app-builder.md"'
alias cc-vibe='claude --prompt-file "$CLAUDE_AGENTS_DIR/36-vibe-code.md"'

# Helper aliases
alias cc-list='ls -1 "$CLAUDE_AGENTS_DIR"/*.md | xargs -n1 basename | grep -v REFERENCE'
alias cc-help='cat "$CLAUDE_AGENTS_DIR/REFERENCE-CARD.md"'
alias cc-edit='$EDITOR "$CLAUDE_AGENTS_DIR"'

# End Claude Code Agents
EOF

echo -e "${GREEN}✓ Added aliases to $SHELL_CONFIG${NC}"
echo ""

# Summary
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              ✅ Setup Complete!                           ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}📁 Location:${NC} $AGENTS_DIR"
echo -e "${YELLOW}📄 Files:${NC} 36 agents + REFERENCE-CARD.md"
echo ""
echo -e "${YELLOW}🔄 To activate the aliases, run:${NC}"
echo -e "   ${CYAN}source $SHELL_CONFIG${NC}"
echo ""
echo -e "${YELLOW}💡 Quick start examples:${NC}"
echo ""
echo -e "${GREEN}  Complete Apps:${NC}"
echo -e "    ${CYAN}cc-build \"Create a todo app with authentication\"${NC}"
echo -e "    ${CYAN}cc-vibe \"Make a cozy journaling app\"${NC}"
echo ""
echo -e "${GREEN}  Development:${NC}"
echo -e "    ${CYAN}cc-react \"Create a UserProfile component\"${NC}"
echo -e "    ${CYAN}cc-api \"Create REST endpoints for posts\"${NC}"
echo -e "    ${CYAN}cc-db \"Design schema for blog platform\"${NC}"
echo ""
echo -e "${GREEN}  Quality:${NC}"
echo -e "    ${CYAN}cc-test \"Generate tests for utils/validation.ts\"${NC}"
echo -e "    ${CYAN}cc-security \"Audit API for vulnerabilities\"${NC}"
echo -e "    ${CYAN}cc-perf \"Optimize Dashboard component\"${NC}"
echo ""
echo -e "${YELLOW}📚 View reference:${NC} ${CYAN}cc-help${NC}"
echo -e "${YELLOW}📋 List agents:${NC} ${CYAN}cc-list${NC}"
echo ""
echo -e "${GREEN}Happy coding! 🚀${NC}"
echo ""
