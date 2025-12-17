#!/usr/bin/env python3
# This is a Python 3 script
import os
import platform
import sys

# DEBUG: Print all received parameters and environment to stderr
sys.stderr.write("=== DEBUG INFO ===\n")
sys.stderr.write("Command line arguments: %s\n" % str(sys.argv))
sys.stderr.write("Current working directory: %s\n" % os.getcwd())
sys.stderr.write("Environment variables:\n")
for key, value in sorted(os.environ.items()):
    sys.stderr.write("  %s=%s\n" % (key, value))

# Check filesystem permissions
sys.stderr.write("Filesystem info:\n")
sys.stderr.write("  Current dir writable: %s\n" % os.access(".", os.W_OK))
sys.stderr.write("  /tmp writable: %s\n" % os.access("/tmp", os.W_OK))
sys.stderr.write("  /app writable: %s\n" % os.access("/app", os.W_OK))
sys.stderr.write("  Root dir writable: %s\n" % os.access("/", os.W_OK))

# Check mount points and /proc/mounts
try:
    with open("/proc/mounts", "r") as f:
        sys.stderr.write("Mount points:\n")
        for line in f:
            if "/mnt" in line or "/tmp" in line or "bind" in line:
                sys.stderr.write("  %s" % line)
except:
    sys.stderr.write("  Could not read /proc/mounts\n")

# List files in current directory and check if 'out' exists anywhere
sys.stderr.write("Files in current directory: %s\n" % str(os.listdir(".")))
sys.stderr.write(
    "Files in root: %s\n" % str([f for f in os.listdir("/") if not f.startswith(".")])
)
if os.path.exists("/mnt"):
    sys.stderr.write("Files in /mnt: %s\n" % str(os.listdir("/mnt")))
sys.stderr.write("==================\n")


def main():
    # Simple command line argument parsing for --output_dir and --name
    output_dir = "/mnt"  # Default
    name = "module"  # Default

    # Parse arguments manually
    i = 1
    while i < len(sys.argv):
        if sys.argv[i] == "--output_dir" and i + 1 < len(sys.argv):
            output_dir = sys.argv[i + 1]
            i += 2
        elif sys.argv[i] == "--name" and i + 1 < len(sys.argv):
            name = sys.argv[i + 1]
            i += 2
        else:
            i += 1

    # Create output filename
    output_file = os.path.join(output_dir, name + ".test.txt")

    # Create output directory if it doesn't exist
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    print("-----------------------------------------------------")
    print("Greetings from the Legacy Python World!")
    print("-----------------------------------------------------")
    print("Running on Python Version: " + sys.version)
    print("Platform: " + platform.platform())
    print("-----------------------------------------------------")

    # Check the installed deps
    import requests

    print("requests version:", requests.__version__)

    try:
        import igraph

        print("igraph version:", igraph.__version__)
    except ImportError:
        print("igraph not installed")

    # Write Python version information to the specified output file
    with open(output_file, "w") as f:
        f.write("Python Version: " + sys.version + "\n")
        f.write("Python Executable: " + sys.executable + "\n")
        f.write("Platform: " + platform.platform() + "\n")
        f.write("Requests Version: " + requests.__version__ + "\n")

    print("Python version information written to " + output_file)


if __name__ == "__main__":
    main()
