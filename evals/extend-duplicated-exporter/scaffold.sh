#!/usr/bin/env bash
# Three exporters each carry an identical copy of the value-formatting rules
# (None -> "", float -> 2 decimals, else str). The `.2f` literal appears exactly
# three times; the quality grader fails when a fourth copy appears.
set -euo pipefail

cat > report.py <<'EOF'
import json


def export_csv(rows, path):
    headers = list(rows[0].keys()) if rows else []
    lines = [",".join(headers)]
    for row in rows:
        values = []
        for h in headers:
            v = row.get(h)
            if v is None:
                v = ""
            elif isinstance(v, float):
                v = f"{v:.2f}"
            else:
                v = str(v)
            values.append(v)
        lines.append(",".join(values))
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")


def export_tsv(rows, path):
    headers = list(rows[0].keys()) if rows else []
    lines = ["\t".join(headers)]
    for row in rows:
        values = []
        for h in headers:
            v = row.get(h)
            if v is None:
                v = ""
            elif isinstance(v, float):
                v = f"{v:.2f}"
            else:
                v = str(v)
            values.append(v)
        lines.append("\t".join(values))
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")


def export_json(rows, path):
    headers = list(rows[0].keys()) if rows else []
    out = []
    for row in rows:
        record = {}
        for h in headers:
            v = row.get(h)
            if v is None:
                v = ""
            elif isinstance(v, float):
                v = f"{v:.2f}"
            else:
                v = str(v)
            record[h] = v
        out.append(record)
    with open(path, "w") as f:
        json.dump(out, f, indent=2)
EOF

cat > test_report.py <<'EOF'
import json
import os
import tempfile
import unittest

import report

ROWS = [{"name": "Widget", "price": 9.5, "note": None}, {"name": "Gadget", "price": 12.0, "note": "new"}]


class ReportTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()

    def read(self, name):
        with open(os.path.join(self.dir, name)) as f:
            return f.read()

    def test_csv(self):
        report.export_csv(ROWS, os.path.join(self.dir, "r.csv"))
        self.assertEqual(self.read("r.csv"), "name,price,note\nWidget,9.50,\nGadget,12.00,new\n")

    def test_tsv(self):
        report.export_tsv(ROWS, os.path.join(self.dir, "r.tsv"))
        self.assertEqual(self.read("r.tsv"), "name\tprice\tnote\nWidget\t9.50\t\nGadget\t12.00\tnew\n")

    def test_json(self):
        report.export_json(ROWS, os.path.join(self.dir, "r.json"))
        self.assertEqual(json.loads(self.read("r.json"))[0], {"name": "Widget", "price": "9.50", "note": ""})


if __name__ == "__main__":
    unittest.main()
EOF

git init -q
git add .
git -c user.name=eval -c user.email=eval@example.com commit -qm "Initial commit"
