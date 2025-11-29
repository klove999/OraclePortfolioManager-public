# ===============================================
# Oracle Portfolio Manager - Makefile for Git Bash
# ===============================================

.PHONY: dev clean venv

dev:
	@echo "[STEP] Setting up local Python environment..."
	@if [ ! -d ".venv" ]; then \
		python3 -m venv .venv && echo "[OK] Virtual environment created."; \
	else \
		echo "[INFO] Virtual environment already exists."; \
	fi
	@echo "[STEP] Installing dependencies..."
	@if [ -f ".venv/bin/activate" ]; then \
		source .venv/bin/activate; \
	elif [ -f ".venv/Scripts/activate" ]; then \
		source .venv/Scripts/activate; \
	else \
		echo "[ERROR] Could not locate venv activation script."; \
		exit 1; \
	fi; \
	pip install --upgrade pip && \
	if [ -f requirements.txt ]; then \
		pip install -r requirements.txt; \
	else \
		echo "[WARN] requirements.txt not found, skipping."; \
	fi
	@echo "[OK] Dependencies installed."
	@echo "[STEP] Launching VS Code..."
	code .

clean:
	@echo "[CLEAN] Removing virtual environment..."
	rm -rf .venv
	@echo "[OK] Clean complete."

venv:
	@echo "[STEP] Rebuilding Python environment..."
	make -f Makefile.bash clean
	make -f Makefile.bash dev
