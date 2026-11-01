# ==============================================================================
# BanglaWrite AI — Native macOS Makefile
# Target: macOS 12 Monterey (Intel x86_64)
# ==============================================================================

SHELL := /bin/bash
.DEFAULT_GOAL := all

APP_NAME     := BanglaWriteAI
BUILD_DIR    := build
APP_BUNDLE   := $(BUILD_DIR)/$(APP_NAME).app
CLI_BIN      := $(BUILD_DIR)/$(APP_NAME)
SCRIPT       := Scripts/build.sh

.PHONY: all build cli app bundle verify test run-cli run-app clean install

all: build verify

build: bundle

bundle app:
	@chmod +x $(SCRIPT)
	@$(SCRIPT) bundle

cli:
	@chmod +x $(SCRIPT)
	@$(SCRIPT) compile

verify test:
	@chmod +x $(SCRIPT)
	@$(SCRIPT) verify

run-cli: cli
	@echo "Launching BanglaWrite AI in standalone CLI mode..."
	@"$(CLI_BIN)"

run-app: bundle
	@echo "Launching BanglaWrite AI application bundle..."
	@open "$(APP_BUNDLE)"

clean:
	@chmod +x $(SCRIPT)
	@$(SCRIPT) clean

install: bundle
	@echo "Installing $(APP_NAME).app to /Applications..."
	@pkill -x $(APP_NAME) || true
	@rm -rf /Applications/$(APP_NAME).app
	@cp -R "$(APP_BUNDLE)" /Applications/
	@echo "Installed successfully to /Applications/$(APP_NAME).app"
