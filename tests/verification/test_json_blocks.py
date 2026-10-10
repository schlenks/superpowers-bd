"""JSON extraction shared by reviewer benchmark scorers."""

import json
import unittest

from tests.verification.json_blocks import find_json_objects


class JsonBlocksTest(unittest.TestCase):
    def test_braces_inside_summary_do_not_break_complete_answer(self):
        answer = {"areas": {"A1": {"found": True, "summary": 'missing {task and stray } plus \\"quote\\"'}}}
        text = "Review notes\n```json\n" + json.dumps(answer) + "\n```\n"
        candidates = [json.loads(block) for block in find_json_objects(text)]
        self.assertIn(answer, candidates)

    def test_malformed_prefix_does_not_hide_later_json(self):
        answer = {"areas": {"A1": {"found": False}}}
        text = "broken { prefix\n" + json.dumps(answer)
        candidates = [json.loads(block) for block in find_json_objects(text)]
        self.assertIn(answer, candidates)


if __name__ == "__main__":
    unittest.main()
