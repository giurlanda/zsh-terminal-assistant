#!/usr/bin/env python3
"""End-to-end tests of the ZLE widgets: drives an interactive zsh through a
pseudo-terminal, with the fake curl from tests/bin. Standard library only.

Usage: python3 tests/widgets_test.py [name-filter]

Set ZTA_TEST_PLUGINS to a colon-separated list of plugin files (e.g.
zsh-autosuggestions.zsh:zsh-syntax-highlighting.zsh) to run the suite with
other plugins loaded after this one.
"""

import fcntl
import json
import os
import pty
import re
import select
import shutil
import signal
import struct
import sys
import tempfile
import termios
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FIXTURES = os.path.join(ROOT, "tests", "fixtures")
CTRL_B, CTRL_C, CTRL_G, CTRL_T = "\x02", "\x03", "\x07", "\x14"
# A UTF-8 locale is needed for ⏳ and ▶ (C.UTF-8 on Linux, en_US.UTF-8 on macOS).
LOCALE = os.environ.get("ZTA_TEST_LOCALE", "C.UTF-8" if sys.platform.startswith("linux") else "en_US.UTF-8")
ANSI = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]|\x1b[=>]|\r")


def ours(highlight):
    """True if region_highlight still contains the plugin's own styles."""
    return "fg=cyan" in highlight or "fg=8" in highlight or "fg=yellow" in highlight


class Shell:
    """An interactive `zsh -f` with the plugin loaded, in a pseudo-terminal."""

    def __init__(self, answer=None, response_file=None, **env):
        self.tmp = tempfile.mkdtemp(prefix="zta-pty.")
        if answer is not None:
            response_file = os.path.join(self.tmp, "response.json")
            with open(response_file, "w") as f:
                json.dump({"choices": [{"message": {"content": answer}}]}, f)
        environ = {
            "PATH": os.path.join(ROOT, "tests", "bin") + os.pathsep + os.environ["PATH"],
            "HOME": self.tmp,
            "TERM": "xterm-256color",
            "LANG": LOCALE,
            "LC_ALL": LOCALE,
            "MOCK_DIR": self.tmp,
            "MOCK_RESPONSE": response_file or "",
            "ZTA_OPENROUTER_API_KEY": "test-key",
            "ZTA_RENDERER": "builtin",
        }
        environ.update({k: str(v) for k, v in env.items()})

        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            os.execvpe("zsh", ["zsh", "-f", "-i"], environ)
        fcntl.ioctl(self.fd, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 100, 0, 0))
        self.output = ""
        self.send(
            "PS1='> '; setopt interactivecomments; "
            f"source {ROOT}/zsh-terminal-assistant.plugin.zsh; "
            + "".join(f"source {p}; " for p in os.environ.get("ZTA_TEST_PLUGINS", "").split(":") if p)
            + 
            # Ctrl+T dumps the editor state to a file for inspection.
            "zta-dump() { print -rl -- \"$BUFFER\" \"$POSTDISPLAY\" \"${region_highlight[*]}\" "
            f">| {self.tmp}/state }}; zle -N zta-dump; bindkey '^T' zta-dump; "
            "print READY\r"
        )
        self.expect("\r\nREADY")

    def send(self, keys):
        os.write(self.fd, keys.encode())

    def read(self, timeout=0.2):
        end = time.time() + timeout
        while time.time() < end:
            ready, _, _ = select.select([self.fd], [], [], 0.05)
            if ready:
                try:
                    self.output += os.read(self.fd, 65536).decode(errors="replace")
                except OSError:
                    break

    def expect(self, text, timeout=5):
        start = len(self.output)
        end = time.time() + timeout
        while time.time() < end:
            self.read(0.1)
            if text in self.output[start:] or text in ANSI.sub("", self.output[start:]):
                return
        raise AssertionError(f"timeout waiting for {text!r}; got {self.output[start:]!r}")

    def mark(self):
        """Position in the output after everything received so far."""
        self.read(0.3)
        return len(self.output)

    def since(self, mark, plain=True):
        text = self.output[mark:]
        return ANSI.sub("", text) if plain else text

    def state(self):
        """Return (BUFFER, POSTDISPLAY, region_highlight) via the Ctrl+T dump widget."""
        path = os.path.join(self.tmp, "state")
        if os.path.exists(path):
            os.remove(path)
        self.send(CTRL_T)
        end = time.time() + 5
        while not os.path.exists(path) and time.time() < end:
            self.read(0.05)
        self.read(0.1)
        with open(path) as f:
            lines = f.read().split("\n")
        return lines[0], lines[1], lines[2]

    def close(self):
        try:
            os.kill(self.pid, signal.SIGKILL)
            os.waitpid(self.pid, 0)
        except OSError:
            pass
        os.close(self.fd)
        shutil.rmtree(self.tmp, ignore_errors=True)


def test_short_mode_accept():
    sh = Shell(answer="echo ZTA_ACCEPTED_$((6*7))")
    try:
        sh.send("# say the answer")
        mark = sh.mark()
        sh.send(CTRL_G)
        sh.expect("Enter = accept  |  Any other key = restore")
        sh.read(0.2)
        raw = sh.since(mark, plain=False)
        cyan = raw[raw.index("\x1b[36m"):raw.index("\x1b[39m", raw.index("\x1b[36m"))]
        assert ANSI.sub("", cyan) == "echo ZTA_ACCEPTED_$((6*7))", f"suggestion not shown in cyan: {raw!r}"
        sh.send("\r")
        buffer, postdisplay, highlight = sh.state()
        assert buffer == "echo ZTA_ACCEPTED_$((6*7))", buffer
        assert postdisplay == "" and not ours(highlight), (postdisplay, highlight)
        # A second Enter executes the command.
        mark = sh.mark()
        sh.send("\r")
        sh.expect("ZTA_ACCEPTED_42\r\n")
    finally:
        sh.close()


def test_short_mode_restore():
    sh = Shell(answer="rm -rf build")
    try:
        sh.send("# delete the build dir" + CTRL_G)
        sh.expect("Enter = accept")
        sh.send("x")
        buffer, postdisplay, highlight = sh.state()
        assert buffer == "# delete the build dir", buffer
        assert postdisplay == "" and not ours(highlight), (postdisplay, highlight)
    finally:
        sh.close()


def test_short_mode_restore_with_ctrl_c():
    sh = Shell(answer="rm -rf build")
    try:
        sh.send("# delete the build dir" + CTRL_G)
        sh.expect("Enter = accept")
        sh.send(CTRL_C)
        sh.read(0.3)  # let the INT trap run before sending the next key
        buffer, postdisplay, highlight = sh.state()
        assert buffer == "# delete the build dir", buffer
        assert postdisplay == "" and not ours(highlight), (postdisplay, highlight)
    finally:
        sh.close()


def test_short_mode_restore_with_escape_sequence():
    sh = Shell(answer="ls")
    try:
        sh.send("# list" + CTRL_G)
        sh.expect("Enter = accept")
        sh.send("\x1b[A")  # Up arrow: must not leak "[A" into the buffer
        buffer, _, _ = sh.state()
        assert buffer == "# list", buffer
    finally:
        sh.close()


def test_spinner_and_cancel():
    sh = Shell(answer="ls", MOCK_DELAY=5)
    try:
        sh.send("# slow request")
        mark = sh.mark()
        sh.send(CTRL_G)
        sh.expect("⏳")
        assert "slow request" not in sh.since(mark), "request still visible while waiting"
        start = time.time()
        sh.send(CTRL_C)
        sh.read(0.3)
        buffer, postdisplay, _ = sh.state()
        assert time.time() - start < 2, "cancel took too long"
        assert buffer == "# slow request", f"buffer not restored: {buffer!r}"
        assert postdisplay == "", postdisplay
    finally:
        sh.close()


def alive(pid_file):
    """True if the process is running. Zombies count as dead: in containers
    PID 1 may never reap the orphans of the killed request."""
    try:
        with open(pid_file) as f:
            pid = int(f.read())
        os.kill(pid, 0)
    except (OSError, ValueError):
        return False
    return not os.popen(f"ps -o stat= -p {pid}").read().strip().startswith("Z")


def test_cancel_with_escape_kills_request():
    sh = Shell(answer="ls", MOCK_DELAY=5)
    try:
        sh.send("# slow request" + CTRL_G)
        sh.expect("⏳")
        time.sleep(0.5)
        curl_pid, sleep_pid = (os.path.join(sh.tmp, f) for f in ("curl.pid", "sleep.pid"))
        assert alive(curl_pid) and alive(sleep_pid), "request not running"
        sh.send("\x1b")
        sh.read(0.3)  # a lone Esc, not the start of an escape sequence
        buffer, _, _ = sh.state()
        assert buffer == "# slow request", buffer
        time.sleep(0.3)
        assert not alive(curl_pid) and not alive(sleep_pid), "background request still running"
    finally:
        sh.close()


def test_short_mode_error():
    sh = Shell(response_file=os.path.join(FIXTURES, "error.json"), MOCK_HTTP_CODE=401)
    try:
        sh.send("# list files" + CTRL_G)
        sh.expect("zta: openrouter: Incorrect API key provided")
        buffer, _, _ = sh.state()
        assert buffer == "# list files", buffer
    finally:
        sh.close()


def test_empty_request():
    sh = Shell(answer="ls")
    try:
        sh.send("#  " + CTRL_G)
        sh.expect("zta: type a request first")
    finally:
        sh.close()


def test_long_mode():
    with open(os.path.join(FIXTURES, "long.md")) as f:
        markdown = f.read()
    sh = Shell(answer=markdown)
    try:
        sh.send("# explain something")
        mark = sh.mark()
        sh.send(CTRL_B)
        sh.expect("item one")
        sh.read(0.5)
        out = sh.since(mark)
        assert "# explain something" in out, "question not kept on screen"
        assert "Title" in out and "• item one" in out and 'echo "**not bold**"' in out, out
        assert "**bold**" not in out.replace('"**not bold**"', ""), "bold markers not rendered"
        buffer, _, _ = sh.state()
        assert buffer == "", buffer
    finally:
        sh.close()


def test_history_option():
    sh = Shell(answer="ls", ZTA_HISTORY="true")
    try:
        sh.send("# list files" + CTRL_G)
        sh.expect("Enter = accept")
        sh.send("\r")
        sh.send("\x15")  # Ctrl+U: clear the line
        mark = sh.mark()
        sh.send("fc -ln -1\r")
        sh.expect("# list files")
        assert "# list files" in sh.since(mark)
    finally:
        sh.close()


def main():
    tests = [(name, fn) for name, fn in globals().items() if name.startswith("test_")]
    selected = sys.argv[1] if len(sys.argv) > 1 else ""
    failed = 0
    for name, fn in tests:
        if selected and selected not in name:
            continue
        try:
            fn()
            print(f"ok   {name}")
        except AssertionError as e:
            failed += 1
            print(f"FAIL {name}\n    {e}")
    print(f"\n{len(tests) - failed} passed, {failed} failed" if not selected else "")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
