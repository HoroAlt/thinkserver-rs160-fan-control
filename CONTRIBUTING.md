# Contributing

## Pushing commits

This account has a quirk: **commits pushed via `git push` over a Personal Access
Token are not linked to the HoroAlt profile** — they show up with the default
gray avatar. Commits made through the GitHub Contents API **do** link correctly.

Use the Contents API to push. For each changed file:

```bash
TOKEN="ghp_..."   # PAT with `repo` scope
REPO="HoroAlt/thinkserver-rs160-fan-control"
MSG="your commit message"

# Get current SHA of the file (use the ref you want to base on)
SHA=$(curl -s -H "Authorization: token $TOKEN" \
  "https://api.github.com/repos/$REPO/contents/fanctl?ref=main" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['sha'])")

# PUT new content
python3 << EOF > /tmp/payload.json
import json, base64
content = base64.b64encode(open("fanctl","rb").read()).decode()
print(json.dumps({
    "message": "$MSG",
    "content": content,
    "sha": "$SHA"
}))
EOF

curl -s -X PUT \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$REPO/contents/fanctl" \
  --data @/tmp/payload.json
```

For multi-file changes, repeat the block per file. Each file becomes its own
commit with the same message — squash later via the web UI if you want one commit.

## Verifying the commit is linked

After pushing, check that GitHub recognized the author:

```bash
curl -s "https://api.github.com/repos/$REPO/commits/<sha>" | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('author') or 'NOT LINKED')"
```

If you see `NOT LINKED`, the commit will show a gray avatar on the commit page.

## Token safety

The PAT is used directly in shell commands. Two rules:

- **Never commit the token** — it should never appear in any file tracked by git.
- **Revoke after use** — at https://github.com/settings/tokens. PATs that show
  up in chat logs, shell history, or screenshots must be rotated.