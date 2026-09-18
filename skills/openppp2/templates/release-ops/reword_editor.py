#!/usr/bin/env python3
"""GIT_EDITOR: provide commit messages for reworded commits in squash order.
Usage: GIT_EDITOR="python3 reword_editor.py" git rebase -i <base>
(reword counter file path is hardcoded below; keep it outside the repo)
"""
import sys

counter_file = '/tmp/reword_counter'
try:
    n = int(open(counter_file).read().strip() or '0')
except Exception:
    n = 0

# ==== EDIT THESE PER USE: one message per reworded commit, in order ====
messages = [
    "feat(crypto): <summary>\n\n<detail>",
    "feat(transmission): <summary>\n\n<detail>",
    "test(crypto): <summary>\n\n<detail>",
]
# =========================================================================

open(sys.argv[1], 'w').write(messages[n] + '\n')
open(counter_file, 'w').write(str(n + 1))
print(f"reword {n}: {messages[n].splitlines()[0]}")
