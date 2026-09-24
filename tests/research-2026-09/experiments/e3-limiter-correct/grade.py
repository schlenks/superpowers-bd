import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2]))
from e3_grade import grade_review


def grade(work, run):
    return grade_review(work, run, kind='correct')
