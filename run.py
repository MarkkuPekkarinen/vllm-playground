#!/usr/bin/env python3
"""
Launcher script for vLLM Playground with process management
"""
import sys
import os
import signal
import atexit
import psutil
from pathlib import Path
from typing import Optional

# Add the parent directory to path to import vllm
parent_dir = Path(__file__).parent.parent
sys.path.insert(0, str(parent_dir))

# PID file location
PID_FILE = Path(__file__).parent / ".vllm_playground.pid"


def get_existing_process() -> Optional[psutil.Process]:
    """Check if a process is already running based on PID file"""
    if not PID_FILE.exists():
        return None
    
    try:
        with open(PID_FILE, 'r') as f:
            pid = int(f.read().strip())
        
        # Check if process exists and is still running
        if psutil.pid_exists(pid):
            proc = psutil.Process(pid)
            # Verify it's actually our process (check command line)
            cmdline = ' '.join(proc.cmdline())
            if 'run.py' in cmdline or 'vllm-playground' in cmdline or 'app.py' in cmdline:
                return proc
    except (ValueError, psutil.NoSuchProcess, psutil.AccessDenied):
        pass
    
    # PID file exists but process doesn't, clean it up
    PID_FILE.unlink(missing_ok=True)
    return None


def kill_existing_process(proc: psutil.Process) -> bool:
    """Kill an existing process"""
    try:
        print(f"Terminating existing process (PID: {proc.pid})...")
        proc.terminate()
        
        # Wait up to 5 seconds for graceful termination
        try:
            proc.wait(timeout=5)
            print("✅ Process terminated successfully")
            return True
        except psutil.TimeoutExpired:
            print("⚠️  Process didn't terminate gracefully, forcing kill...")
            proc.kill()
            proc.wait(timeout=3)
            print("✅ Process killed")
            return True
    except psutil.NoSuchProcess:
        print("✅ Process already terminated")
        return True
    except Exception as e:
        print(f"❌ Error killing process: {e}")
        return False


def write_pid_file():
    """Write current process PID to file"""
    with open(PID_FILE, 'w') as f:
        f.write(str(os.getpid()))


def cleanup_pid_file():
    """Remove PID file on exit"""
    PID_FILE.unlink(missing_ok=True)


def signal_handler(signum, frame):
    """Handle termination signals"""
    print(f"\n🛑 Received signal {signum}, shutting down...")
    cleanup_pid_file()
    sys.exit(0)


if __name__ == "__main__":
    # Check for existing process
    existing_proc = get_existing_process()
    if existing_proc:
        print("=" * 60)
        print("⚠️  WARNING: vLLM Playground is already running!")
        print("=" * 60)
        print(f"\nExisting process details:")
        print(f"  PID: {existing_proc.pid}")
        print(f"  Started: {existing_proc.create_time()}")
        print(f"  Status: {existing_proc.status()}")
        
        # Auto-kill the existing process
        print("\n🔄 Automatically stopping the existing process...")
        if kill_existing_process(existing_proc):
            print("✅ Ready to start new instance\n")
        else:
            print(f"❌ Failed to stop existing process. Please manually kill PID {existing_proc.pid}")
            print(f"   Command: kill {existing_proc.pid}")
            sys.exit(1)
    
    # Register cleanup handlers
    atexit.register(cleanup_pid_file)
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)
    
    # Write PID file
    write_pid_file()
    
    print("=" * 60)
    print("🚀 vLLM Playground - Starting...")
    print("=" * 60)
    print("\nFeatures:")
    print("  ⚙️  Configure vLLM servers")
    print("  💬 Chat with your models")
    print("  📋 Real-time log streaming")
    print("  🎛️  Full server control")
    print("\nAccess the Playground at: http://localhost:7860")
    print("Press Ctrl+C to stop\n")
    print(f"Process ID: {os.getpid()}")
    print(f"PID file: {PID_FILE}")
    print("=" * 60)
    
    try:
        from app import main
        main()
    except KeyboardInterrupt:
        print("\n🛑 Interrupted by user")
    except Exception as e:
        print(f"\n❌ Error: {e}")
        sys.exit(1)
    finally:
        cleanup_pid_file()

