# vLLM Playground Scripts

This directory contains utility scripts for managing the vLLM Playground.

## Process Management Scripts

### kill_playground.py

Manually kill any running vLLM Playground instances.

**Usage:**
```bash
python scripts/kill_playground.py
# or
./scripts/kill_playground.py
```

**What it does:**
- Searches for running vLLM Playground processes
- Attempts graceful termination first (SIGTERM)
- Forces kill if graceful termination fails (SIGKILL)
- Cleans up PID files

**When to use:**
- When `run.py` becomes orphaned after losing connection
- When you want to ensure no other instances are running
- When the automatic process management in `run.py` fails

## Setup Scripts

### install.sh

Install dependencies and set up the environment.

**Usage:**
```bash
./scripts/install.sh
```

### start.sh

Start the vLLM Playground (alternative to `run.py`).

**Usage:**
```bash
./scripts/start.sh
```

### verify_setup.py

Verify that the installation and setup are correct.

**Usage:**
```bash
python scripts/verify_setup.py
```

## CPU-Specific Scripts

### run_cpu.sh

Run vLLM Playground optimized for CPU-only environments.

**Usage:**
```bash
./scripts/run_cpu.sh
```

## Process Management Features

The main `run.py` launcher includes automatic process management:

1. **PID File**: Creates `.vllm_playground.pid` to track the running process
2. **Automatic Detection**: Detects if another instance is already running
3. **Auto-Kill**: Automatically terminates existing instances before starting
4. **Cleanup**: Removes PID files on exit (normal or interrupted)
5. **Signal Handling**: Properly handles SIGTERM and SIGINT (Ctrl+C)

### How It Works

When you start `run.py`:
1. Checks for existing PID file
2. Verifies if the process is still running
3. If found, automatically terminates the old instance
4. Starts the new instance
5. Creates a new PID file with current process ID

When you stop with Ctrl+C or kill the process:
1. Signal handler catches the termination
2. Cleans up the PID file
3. Exits gracefully

### Troubleshooting

**Problem: "Process could not be terminated"**
- Solution: Use `kill_playground.py` to forcefully kill all instances
- Last resort: `ps aux | grep run.py` and `kill -9 <PID>`

**Problem: PID file exists but process is dead**
- The script automatically cleans up stale PID files
- No action needed

**Problem: Multiple instances running**
- Run `kill_playground.py` to terminate all instances
- Then start fresh with `run.py`

## Additional Information

For more details on using the vLLM Playground, see:
- [Main README](../README.md)
- [Quick Start Guide](../docs/QUICKSTART.md)
- [Troubleshooting Guide](../docs/TROUBLESHOOTING.md)

