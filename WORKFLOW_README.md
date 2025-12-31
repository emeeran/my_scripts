# Claude Code Workflow - Optimized Version 2.0

An enhanced bash script for automated code review, refactoring, optimization, documentation, and testing using Claude Code CLI.

## ✨ New Features

### 🚀 Performance & Reliability
- **Retry Logic**: Automatic retry on failure (configurable)
- **Timeout Protection**: Prevents infinite hangs
- **Checkpoint/Resume**: Resume from any failed step
- **Better Error Handling**: Detailed error logging and recovery

### 🎛️ Flexibility
- **Configurable**: Use config files or environment variables
- **Selective Execution**: Skip specific steps
- **Dry Run Mode**: Preview without making changes
- **Verbose Mode**: Detailed logging for debugging

### 🔧 Usability
- **Dependency Checks**: Validates required tools
- **Progress Indicators**: Visual feedback with spinners
- **Better Logging**: Separate error logs, timestamped entries
- **Output Verification**: Checks that expected files are generated

## 📦 Installation

```bash
# Make script executable
chmod +x opti_proj.sh

# Optional: Create config file
cp .claude-workflow.conf.example .claude-workflow.conf
# Edit .claude-workflow.conf with your preferences
```

## 🎯 Usage

### Basic Usage
```bash
# Run all steps on current directory
./opti_proj.sh

# Run on specific project
./opti_proj.sh /path/to/project
```

### Advanced Usage

```bash
# Preview without executing
./opti_proj.sh --dry-run .

# Skip specific steps (e.g., skip refactoring and optimization)
./opti_proj.sh --skip 2,3 .

# Resume from a specific step
./opti_proj.sh --resume 3 .

# Use different model
./opti_proj.sh --model claude-opus-4 .

# Enable verbose logging
./opti_proj.sh --verbose .

# Custom timeout (2 hours)
./opti_proj.sh --timeout 7200 .

# Combine options
./opti_proj.sh -v -s 4 -t 1800 /path/to/project
```

### Using Configuration File

Create `.claude-workflow.conf` in your project:

```bash
# Example configuration
MODEL="claude-sonnet-4-5-20250929"
MAX_RETRIES=3
TIMEOUT=7200
VERBOSE=true
```

Then run:
```bash
./opti_proj.sh --config /path/to/project/.claude-workflow.conf /path/to/project
```

## 📋 Workflow Steps

1. **Code Review** (Step 1)
   - Analyzes code quality, security, bugs
   - Generates `REVIEW_REPORT.md`

2. **Refactoring** (Step 2)
   - Fixes issues from review
   - Improves code structure
   - Generates `REFACTOR_CHANGELOG.md`

3. **Performance Optimization** (Step 3)
   - Identifies bottlenecks
   - Implements optimizations
   - Generates `PERFORMANCE_REPORT.md`

4. **Documentation** (Step 4)
   - Creates/updates README, ARCHITECTURE, API docs
   - Adds inline documentation

5. **Testing** (Step 5)
   - Implements unit, integration, e2e tests
   - Generates `TEST_REPORT.md`

## 🔄 Resume After Failure

If the workflow fails at step 3:

```bash
./opti_proj.sh --resume 3 /path/to/project
```

The script automatically creates checkpoints, so you can also check the last successful step:

```bash
cat .claude-workflow-logs/.checkpoint
```

## 📊 Output Files

The script generates:

### Reports
- `REVIEW_REPORT.md` - Code review findings
- `REFACTOR_CHANGELOG.md` - Refactoring changes
- `PERFORMANCE_REPORT.md` - Performance optimizations
- `TEST_REPORT.md` - Test results and coverage

### Documentation
- `README.md` - Project documentation
- `ARCHITECTURE.md` - System architecture
- `API_DOCUMENTATION.md` - API documentation
- `CONTRIBUTING.md` - Contribution guidelines

### Logs
All logs are saved in `.claude-workflow-logs/`:
- `workflow_TIMESTAMP.log` - Main workflow log
- `errors_TIMESTAMP.log` - Error-specific log
- `01_review_TIMESTAMP.log` - Step 1 details
- `02_refactor_TIMESTAMP.log` - Step 2 details
- ... (one per step)

## ⚙️ Configuration Options

### Environment Variables
```bash
export CLAUDE_MODEL="claude-sonnet-4-5-20250929"
export CLAUDE_WORKFLOW_CONFIG="/path/to/config"
```

### Command Line Options
```
-h, --help              Show help message
-d, --dry-run           Preview without executing
-s, --skip STEP         Skip step(s) (1-5, comma-separated)
-r, --resume STEP       Resume from step
-v, --verbose           Enable verbose output
-p, --parallel          Run independent steps in parallel (experimental)
-m, --model MODEL       Specify Claude model
-t, --timeout SECONDS   Set timeout per step
-c, --config FILE       Use custom config file
```

## 🔍 Troubleshooting

### Command Not Found: claude
```bash
npm install -g @anthropics/claude-cli
```

### Timeout Issues
Increase timeout:
```bash
./opti_proj.sh --timeout 7200 .  # 2 hours
```

### Step Fails Repeatedly
Check detailed logs:
```bash
cat .claude-workflow-logs/errors_*.log
cat .claude-workflow-logs/0X_stepname_*.log
```

Skip problematic step:
```bash
./opti_proj.sh --skip 3 .
```

### Verbose Debugging
```bash
./opti_proj.sh -v . 2>&1 | tee debug.log
```

## 📈 Best Practices

1. **Start Small**: Test on a small project first
2. **Review Reports**: Always review generated reports before committing
3. **Version Control**: Commit before running the workflow
4. **Incremental**: Run steps individually if needed
5. **Monitor**: Watch the logs for any issues
6. **Backup**: Keep backups of important projects

## 🆚 Changes from v1.0

| Feature | v1.0 | v2.0 |
|---------|------|------|
| Error Recovery | ❌ | ✅ Retry + Resume |
| Timeout Protection | ❌ | ✅ Configurable |
| Dependency Checks | ❌ | ✅ Pre-flight validation |
| Configuration Files | ❌ | ✅ Full support |
| Dry Run Mode | ❌ | ✅ Preview changes |
| Skip Steps | ❌ | ✅ Flexible execution |
| Progress Indicators | Basic | ✅ Spinners + colors |
| Logging | Single file | ✅ Separated by type |
| Output Verification | ❌ | ✅ Post-check |

## 🤝 Contributing

Feel free to submit issues and enhancement requests!

## 📝 License

MIT License - Feel free to use and modify as needed.

## 🔗 Related

- [Claude Code CLI Documentation](https://github.com/anthropics/claude-code)
- [Bash Best Practices](https://google.github.io/styleguide/shellguide.html)

---

**Version**: 2.0  
**Last Updated**: 2024
**Author**: Enhanced workflow script
