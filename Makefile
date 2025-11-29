# ============================================================
# Oracle Portfolio Manager - Unified Makefile (Windows + Bash)
# ============================================================

# Detect if running under Git Bash / MINGW64
ifeq ($(findstring MINGW,$(shell uname -s)),MINGW)
	SHELLTYPE := bash
	PYTHON := python3
else ifeq ($(OS),Windows_NT)
	SHELLTYPE := windows
	PYTHON := python
else
	SHELLTYPE := bash
	PYTHON := python3
endif

.PHONY: dev clean venv

dev:
ifeq ($(SHELLTYPE),windows)
	@echo [STEP] Setting up local Python environment (Windows)...
	if not exist .venv ( \
		$(PYTHON) -m venv .venv && echo [OK] Virtual environment created. \
	) else ( \
		echo [INFO] Virtual environment already exists. \
	)
	@echo [STEP] Installing dependencies...
	@.venv\Scripts\python.exe -m pip install --upgrade pip
	@-if exist requirements.txt .venv\Scripts\python.exe -m pip install -r requirements.txt
	@echo [OK] Dependencies installed.
	@echo [STEP] Launching VS Code...
	code .
else
	@echo [STEP] Setting up local Python environment (Bash)...
	@if [ ! -d ".venv" ]; then \
		$(PYTHON) -m venv .venv && echo "[OK] Virtual environment created."; \
	else \
		echo "[INFO] Virtual environment already exists."; \
	fi
	@echo [STEP] Installing dependencies...
	@. .venv/bin/activate && pip install --upgrade pip && ( [ -f requirements.txt ] && pip install -r requirements.txt || echo "[WARN] requirements.txt not found, skipping." )
	@echo [OK] Dependencies installed.
	@echo [STEP] Launching VS Code...
	code .
endif

clean:
	@echo [CLEAN] Removing virtual environment...
ifeq ($(SHELLTYPE),windows)
	@if exist .venv rmdir /s /q .venv
else
	@rm -rf .venv
endif
	@echo [OK] Clean complete.

venv:
	@echo [STEP] Rebuilding Python environment...
	make clean
	make dev
