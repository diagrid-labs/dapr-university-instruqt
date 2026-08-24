import os
from assignment_blocks import parse_blocks, resolve_files
from dapr_workflow_aspire import MANIFEST_CH2, MANIFEST_CH3, MANIFEST_CH4

# libraries/tests/ -> tools/track-tester/libraries/tests -> repo root is 4 up.
_REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))


def _assignment(challenge):
    return os.path.join(_REPO, "dapr-workflow-aspire", challenge, "assignment.md")


def _resolve(challenge, manifest):
    with open(_assignment(challenge), encoding="utf-8") as fh:
        return resolve_files(parse_blocks(fh.read()), manifest)


def test_ch2_manifest_matches_real_assignment():
    assert len(_resolve("2-project-creation", MANIFEST_CH2)) == 1


def test_ch3_manifest_matches_real_assignment():
    assert len(_resolve("3-workflow-definition", MANIFEST_CH3)) == 6


def test_ch4_manifest_matches_real_assignment():
    assert len(_resolve("4-apphost-resources", MANIFEST_CH4)) == 4
