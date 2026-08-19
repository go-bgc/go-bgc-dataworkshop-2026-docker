"""Monkey-patch ipykernel to allow interactive stdin."""
import sys

# Patch ipykernel.kernelbase.Kernel.raw_input to bypass the _allow_stdin check
try:
    from ipykernel import kernelbase

    # Save the original raw_input method
    _original_raw_input = kernelbase.Kernel.raw_input

    def patched_raw_input(self, prompt=''):
        """Override raw_input to bypass _allow_stdin check and allow interactive input."""
        # Call _input_request directly, ignoring the _allow_stdin flag
        return self._input_request(
            str(prompt),
            self._get_shell_context_var(self._shell_parent_ident),
            self.get_parent("shell"),
            password=False,
        )

    # Replace the method
    kernelbase.Kernel.raw_input = patched_raw_input
    print("[Jupyter startup] Patched ipykernel.Kernel.raw_input to allow interactive stdin")

except Exception as e:
    print(f"[Jupyter startup] Warning: Could not patch Kernel.raw_input: {e}")

# Also patch sys.stdin.isatty to report True
sys.stdin.isatty = lambda: True
