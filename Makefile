.PHONY: build app install uninstall run clean

APP_NAME     = AEON Voice
BINARY_NAME  = AEONVoice
BUILD_DIR    = .build/release
APP_BUNDLE   = build/$(APP_NAME).app
INSTALL_DIR  = $(HOME)/Applications

build:
	@echo "Compiling $(BINARY_NAME)..."
	@swift build -c release 2>&1 | grep -v "^$$" | tail -3
	@echo "Done — binary at $(BUILD_DIR)/$(BINARY_NAME)"

app:
	@echo "Creating app bundle..."
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	@# Stamp build commit SHA into BuildInfo.swift then compile
	@BUILD_SHA=$$(git rev-parse --short HEAD 2>/dev/null || echo "dev"); \
	 sed -i '' "s/static let commitSHA = \".*\"/static let commitSHA = \"$$BUILD_SHA\"/" Sources/AEONVoice/BuildInfo.swift; \
	 echo "Compiling $(BINARY_NAME) ($$BUILD_SHA)..."; \
	 swift build -c release 2>&1 | grep -v "^$$" | tail -3
	@cp "$(BUILD_DIR)/$(BINARY_NAME)" "$(APP_BUNDLE)/Contents/MacOS/"
	@# Restore BuildInfo.swift to placeholder so the repo stays clean
	@sed -i '' 's/static let commitSHA = ".*"/static let commitSHA = "dev"/' Sources/AEONVoice/BuildInfo.swift
	@cp resources/Info.plist "$(APP_BUNDLE)/Contents/"
	@test -f resources/AppIcon.icns && cp resources/AppIcon.icns "$(APP_BUNDLE)/Contents/Resources/" || true
	@codesign --force --deep --sign - "$(APP_BUNDLE)" 2>/dev/null || true
	@touch "$(APP_BUNDLE)"
	@echo "Built: $(APP_BUNDLE)"

install:
	@bash scripts/install.sh

uninstall:
	@bash scripts/uninstall.sh

run: app
	@if pgrep -x $(BINARY_NAME) >/dev/null 2>&1; then \
		echo "Stopping running instance..."; \
		osascript -e 'quit app "$(APP_NAME)"' 2>/dev/null || pkill -x $(BINARY_NAME) 2>/dev/null || true; \
		sleep 1; \
	fi
	@open "$(APP_BUNDLE)"

clean:
	swift package clean
	@rm -rf build/
	@echo "Clean."
