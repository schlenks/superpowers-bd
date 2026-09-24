import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2]))
from e5_grade import grade_spec


def grade(work, run):
    return grade_spec(work, run, gaps=False)
