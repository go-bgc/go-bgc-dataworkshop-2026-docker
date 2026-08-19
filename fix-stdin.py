"""Monkey-patch ipykernel to allow interactive stdin."""
import sys

# Patch ipykernel.kernelbase.Kernel to enable stdin support
try:
    from ipykernel import kernelbase

    # Patch raw_input to bypass the _allow_stdin check
    _original_raw_input = kernelbase.Kernel.raw_input

    def patched_raw_input(self, prompt=''):
        """Override raw_input to bypass _allow_stdin check and allow interactive input."""
        return self._input_request(
            str(prompt),
            self._get_shell_context_var(self._shell_parent),
            self.get_parent("shell"),
            password=False,
        )

    kernelbase.Kernel.raw_input = patched_raw_input
    print("[Jupyter startup] Patched ipykernel.Kernel.raw_input to allow interactive stdin")

    # Also set _allow_stdin to True by default when kernel is initialized
    _original_init = kernelbase.Kernel.__init__

    def patched_init(self, **kwargs):
        _original_init(self, **kwargs)
        # Force enable stdin after initialization
        self._allow_stdin = True

    kernelbase.Kernel.__init__ = patched_init
    print("[Jupyter startup] Patched ipykernel.Kernel.__init__ to enable _allow_stdin")

except Exception as e:
    print(f"[Jupyter startup] Warning: Could not patch ipykernel: {e}")

# Also patch sys.stdin.isatty to report True
sys.stdin.isatty = lambda: True
