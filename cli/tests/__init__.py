import sys
from pathlib import Path

# Allow tests to import alloy_cli from the sibling cli directory.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
