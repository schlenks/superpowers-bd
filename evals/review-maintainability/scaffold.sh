#!/usr/bin/env bash
# utils.slugify already exists (and is used by feeds.py). The reviewed change,
# publish.py, re-implements it inline, nests four levels deep, takes an unused
# `verbose` parameter, uses vague names, and has a real bug: tags[1:4] skips
# the first tag although the docstring promises the first three.
set -euo pipefail

cat > utils.py <<'EOF'
import re


def slugify(text):
    """Lowercase, replace runs of non-alphanumerics with '-', trim dashes."""
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
EOF

cat > feeds.py <<'EOF'
from utils import slugify


def feed_entry(post):
    return {"url": f"/posts/{slugify(post['title'])}", "title": post["title"]}
EOF

git init -q
git add .
git -c user.name=eval -c user.email=eval@example.com commit -qm "Initial commit"

cat > publish.py <<'EOF'
import re


def process(posts, flag, verbose):
    """Build publish records for published, titled posts.

    Each record keeps at most the first three tags of the post.
    """
    out = []
    for p in posts:
        if p.get("published"):
            if p.get("title"):
                if flag:
                    if len(p.get("tags", [])) > 0:
                        s = re.sub(r"[^a-z0-9]+", "-", p["title"].lower()).strip("-")
                        out.append({"slug": s, "tags": p["tags"][1:4]})
    return out
EOF

git add publish.py
git -c user.name=eval -c user.email=eval@example.com commit -qm "Add publish records"
