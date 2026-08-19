"""Patch sys.stdin to report isatty=True for better interactive compatibility."""
import sys

original_isatty = sys.stdin.isatty

def patched_isatty():
    # Report as TTY to make interactive libraries work
    # even though stdin is actually a ZMQ socket
    return True

sys.stdin.isatty = patched_isatty