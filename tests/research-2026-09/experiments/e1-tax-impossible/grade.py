import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2]))
from e1_grade import grade_tax


def grade(work, run):
    return grade_tax(work, run, kind='impossible')
