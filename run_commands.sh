#!/usr/bin/env bash
set -euo pipefail

# Udacity Claude AI Engineer — Harness Engineering Capstone
# Runs the completed solution for all four capstone systems.
#
# Usage:
#   chmod +x run_commands.sh
#   ./run_commands.sh
#
# Requirements:
#   - Python 3.11+
#   - git
#   - ANTHROPIC_API_KEY for Systems 1 and 2
#
# System 4 is deliberately run with a recorded response, so it does not
# require an API call.

ROOT="/workspace"
CAPSTONE="$ROOT/Project-Harness Engineering with Claude and Claude Code"
EVIDENCE="$CAPSTONE/evidence"

SYSTEM1="$ROOT/Build a Claims Intake Agent with a stop_reason-Driven Loop/exercises/03-dynamic-decomposition/solution"
SYSTEM2="$ROOT/Engineer a Long-Conversation Context Strategy for a Retail Support Copilot/04-assemble-and-locate/solution"
SYSTEM3="$ROOT/Configure Claude Code for a Multi-Surface Monorepo Team/04-plan-mode-and-explore-decision-doc/solution"
SYSTEM4="$ROOT/Build a Multi-Shift Quality Monitoring System with Claude Orchestration/04-fork-scratchpad/solution"

mkdir -p "$EVIDENCE"/system-1-claims
mkdir -p "$EVIDENCE"/system-2-retail-context
mkdir -p "$EVIDENCE"/system-3-ecommerce-config
mkdir -p "$EVIDENCE"/system-4-shift-monitor

log() {
    echo
    echo "============================================================"
    echo "$1"
    echo "============================================================"
}

check_python() {
    command -v python >/dev/null 2>&1 || {
        echo "ERROR: python command not found."
        exit 1
    }

    python - <<'PY'
import sys
if sys.version_info < (3, 11):
    raise SystemExit(
        f"ERROR: Python 3.11+ required; found {sys.version.split()[0]}"
    )
print("Python:", sys.version.split()[0])
PY
}

make_venv() {
    local dir="$1"
    local name="$2"

    if [ ! -d "$dir/.venv" ]; then
        echo "Creating $name virtual environment..."
        python -m venv "$dir/.venv"
    fi

    # shellcheck disable=SC1091
    source "$dir/.venv/bin/activate"
    python -m pip install --upgrade pip
}

deactivate_env() {
    deactivate 2>/dev/null || true
}

check_project_dirs() {
    for dir in "$SYSTEM1" "$SYSTEM2" "$SYSTEM3" "$SYSTEM4"; do
        if [ ! -d "$dir" ]; then
            echo "ERROR: Missing project directory:"
            echo "  $dir"
            exit 1
        fi
    done
}

check_python
check_project_dirs

if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
    echo
    echo "ERROR: ANTHROPIC_API_KEY is not set."
    echo
    echo 'Set it in the terminal with:'
    echo '  export ANTHROPIC_API_KEY="YOUR_API_KEY"'
    echo
    echo "Systems 1 and 2 require the live Claude API."
    echo "System 3 and System 4 (offline recorded-response mode) do not."
    exit 1
fi

# ---------------------------------------------------------------------------
# SYSTEM 1 — Insurance Claims Intake Agent
# ---------------------------------------------------------------------------
log "SYSTEM 1 — Claims Intake Agent"

cd "$SYSTEM1"
make_venv "$SYSTEM1" "System 1"

echo "Installing System 1..."
pip install -e ".[dev]"

echo "Running System 1 tests..."
pytest tests/ -v 2>&1 | tee "$EVIDENCE/system-1-claims/pytest.txt"

echo "Running System 1 end-to-end..."
python -m claims_intake.run --all 2>&1 | tee "$EVIDENCE/system-1-claims/run.txt"

# Copy the latest generated run artifacts into evidence.
if [ -d "$SYSTEM1/runs" ]; then
    latest_run="$(find "$SYSTEM1/runs" -mindepth 1 -maxdepth 1 -type d | sort | tail -n 1 || true)"
    if [ -n "$latest_run" ]; then
        rm -rf "$EVIDENCE/system-1-claims/latest-run"
        cp -R "$latest_run" "$EVIDENCE/system-1-claims/latest-run"
        echo "System 1 evidence copied from: $latest_run"
    fi
fi

deactivate_env

# ---------------------------------------------------------------------------
# SYSTEM 2 — Retail Support Context Strategy
# ---------------------------------------------------------------------------
log "SYSTEM 2 — Retail Support Context Strategy"

cd "$SYSTEM2"
make_venv "$SYSTEM2" "System 2"

echo "Installing System 2..."
pip install -e ".[dev]"

echo "Running System 2 tests..."
pytest tests/ -v 2>&1 | tee "$EVIDENCE/system-2-retail-context/pytest.txt"

echo "Running System 2 end-to-end..."
python -m retail_context.run --all 2>&1 | tee "$EVIDENCE/system-2-retail-context/run.txt"

if [ -d "$SYSTEM2/runs" ]; then
    latest_run="$(find "$SYSTEM2/runs" -mindepth 1 -maxdepth 1 -type d | sort | tail -n 1 || true)"
    if [ -n "$latest_run" ]; then
        rm -rf "$EVIDENCE/system-2-retail-context/latest-run"
        cp -R "$latest_run" "$EVIDENCE/system-2-retail-context/latest-run"
        echo "System 2 evidence copied from: $latest_run"
    fi
fi

deactivate_env

# ---------------------------------------------------------------------------
# SYSTEM 3 — E-Commerce Team Claude Code Config
# ---------------------------------------------------------------------------
log "SYSTEM 3 — E-Commerce Team Claude Code Config"

cd "$SYSTEM3"
make_venv "$SYSTEM3" "System 3"

echo "Installing System 3..."
pip install -e ".[dev]"

echo "Running System 3 tests..."
pytest tests/ -v 2>&1 | tee "$EVIDENCE/system-3-ecommerce-config/pytest.txt"

echo "Running System 3 validator..."
python -m ecommerce_team_config . 2>&1 | tee "$EVIDENCE/system-3-ecommerce-config/validator.txt"

echo "Copying System 3 Claude configuration..."
if [ -d "$SYSTEM3/.claude" ]; then
    rm -rf "$EVIDENCE/system-3-ecommerce-config/.claude"
    cp -R "$SYSTEM3/.claude" "$EVIDENCE/system-3-ecommerce-config/.claude"
fi

if [ -f "$SYSTEM3/CLAUDE.md" ]; then
    cp "$SYSTEM3/CLAUDE.md" "$EVIDENCE/system-3-ecommerce-config/CLAUDE.md"
fi

deactivate_env

# ---------------------------------------------------------------------------
# SYSTEM 4 — Multi-Shift Quality Monitoring
# ---------------------------------------------------------------------------
log "SYSTEM 4 — Multi-Shift Quality Monitoring"

cd "$SYSTEM4"
make_venv "$SYSTEM4" "System 4"

echo "Installing System 4..."
pip install -e ".[dev]"

echo "Running System 4 tests..."
pytest tests/ -v 2>&1 | tee "$EVIDENCE/system-4-shift-monitor/pytest.txt"

echo "Seeding System 4 warm database..."
python -c "import json; from pathlib import Path; from shift_monitor.warm import WarmStore; w=WarmStore(Path('data/warm.sqlite')); w.initialize(); w.insert_many(json.load(open('fixtures/defects.json')))"

echo "Running System 4 offline with recorded response..."
python -m shift_monitor run-shift \
  --shift C \
  --warm-db data/warm.sqlite \
  --recorded-response fixtures/recorded_responses/shift_C_2026-04-30.json \
  2>&1 | tee "$EVIDENCE/system-4-shift-monitor/run.txt"

if [ -f "$SYSTEM4/data/hot_state.json" ]; then
    cp "$SYSTEM4/data/hot_state.json" "$EVIDENCE/system-4-shift-monitor/hot_state.json"
    echo "hot_state.json size:"
    wc -c "$SYSTEM4/data/hot_state.json" | tee "$EVIDENCE/system-4-shift-monitor/hot_state_size.txt"
fi

if [ -f "$SYSTEM4/data/shift_scratchpad.jsonl" ]; then
    cp "$SYSTEM4/data/shift_scratchpad.jsonl" "$EVIDENCE/system-4-shift-monitor/shift_scratchpad.jsonl"
fi

deactivate_env

# ---------------------------------------------------------------------------
# FINAL SUMMARY
# ---------------------------------------------------------------------------
log "CAPSTONE RUN COMPLETE"

cd "$CAPSTONE"

echo "Evidence directory:"
find "$EVIDENCE" -maxdepth 2 -type f | sort

echo
echo "Next steps:"
echo "1. Open:"
echo "   $CAPSTONE/reflection-brief-template.md"
echo "2. Complete it using the evidence generated above."
echo "3. From /workspace run:"
echo "   git status"
echo "   git add ."
echo "   git status"
echo "4. Commit and push only after checking that no secrets are staged."
echo
echo "IMPORTANT: Do not commit .env files, API keys, credentials, or secrets."
