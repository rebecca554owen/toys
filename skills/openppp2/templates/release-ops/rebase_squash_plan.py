#!/usr/bin/env python3
"""GIT_SEQUENCE_EDITOR: rewrite rebase todo to squash commits into groups.
Usage: GIT_SEQUENCE_EDITOR="python3 rebase_squash_plan.py" git rebase -i <base>

Edit the maps below per use:
- fixup_map:  {short_sha: 'fixup'}  — commits folded into the group leader (uses their message)
- reword_set: {short_sha}           — group leaders whose message gets rewritten (needs GIT_EDITOR too)
"""
import sys

todo_path = sys.argv[1]
with open(todo_path) as f:
    lines = f.read().splitlines()

# ==== EDIT THESE PER USE (sha prefixes as they appear in the todo) ====
fixup_map = {
    # '572e328f': 'fixup',
}
reword_set = {
    # '202100bb',
}
# ======================================================================

out = []
for line in lines:
    if not line.strip() or line.startswith('#'):
        continue
    parts = line.split()
    if len(parts) < 2:
        out.append(line)
        continue
    action, sha = parts[0], parts[1]
    rest = line.split(None, 2)[2] if len(line.split(None, 2)) > 2 else ''
    if sha in fixup_map:
        out.append(f"fixup {sha} {rest}".rstrip())
    elif sha in reword_set:
        out.append(f"reword {sha} {rest}".rstrip())
    else:
        out.append(line)

with open(todo_path, 'w') as f:
    f.write('\n'.join(out) + '\n')
print("TODO rewritten:")
for l in out:
    print(" ", l[:90])
