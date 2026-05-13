#!/bin/bash
# PPT Full Pipeline - 一键初始化脚本
set -e

echo "=== PPT Full Pipeline Setup ==="

# 1. Check Hermes
if [ ! -d "$HOME/AppData/Local/hermes" ]; then
    echo "ERROR: Hermes Agent not found. Install first: https://hermes-agent.nousresearch.com/docs"
    exit 1
fi

# 2. Copy skill
SKILL_DIR="$HOME/AppData/Local/hermes/skills/productivity/ppt-full-pipeline"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ "$SCRIPT_DIR" != "$SKILL_DIR" ]; then
    echo "Copying skill to Hermes..."
    cp -r "$SCRIPT_DIR/.." "$SKILL_DIR"
fi

# 3. Check Node.js
if ! command -v node &> /dev/null; then
    echo "WARNING: Node.js not found. Install from https://nodejs.org"
else
    echo "Node.js: $(node -v)"
fi

# 4. Check Python
if ! command -v python &> /dev/null; then
    echo "WARNING: Python not found"
else
    echo "Python: $(python --version)"
fi

# 5. Install npm deps
if command -v npm &> /dev/null; then
    echo "Installing npm dependencies..."
    npm install -g pptxgenjs 2>/dev/null || echo "  pptxgenjs already installed or failed"
fi

# 6. Install Python deps
if command -v pip &> /dev/null; then
    echo "Installing Python dependencies..."
    pip install python-pptx matplotlib pymupdf -q 2>/dev/null || echo "  Some packages may already be installed"
fi

echo ""
echo "=== Setup Complete ==="
echo "Next steps:"
echo "1. Clone ppt-master: git clone https://github.com/hugohe3/ppt-master.git"
echo "2. Set API keys: export OPENAI_API_KEY=sk-xxx"
echo "3. Restart Hermes"
echo "4. Send: 用 ppt-full-pipeline 生成 PPT"
