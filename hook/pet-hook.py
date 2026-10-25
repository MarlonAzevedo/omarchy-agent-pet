#!/usr/bin/env python3
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
# Roda dentro da pasta do plugin: __pycache__ ali faria o shell recarregar
sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT))

from agent_pet.hooks import main


if __name__ == "__main__":
    raise SystemExit(main())
