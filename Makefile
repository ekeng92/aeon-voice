.PHONY: build app install uninstall run clean

APP_NAME     = AEON Voice
BINARY_NAME  = AEONVoice
BUILD_DIR    = .build/release
APP_BUNDLE   = build/$(APP_NAME).app
INSTALL_DIR  = $(HOME)/Applications

build:
	@echo "Building $(BINARY_NAME)..."
	swift build -c release
	@echo "Done — binary at $(BUILD_DIR)/$(BINARY_NAME)"

app: build
	@echo "Creating app bundle..."
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	@cp "$(BUILD_DIR)/$(BINARY_NAME)" "$(APP_BUNDLE)/Contents/MacOS/"
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
	@open "$(APP_BUNDLE)"

clean:
	swift package clean
	@rm -rf build/
	@echo "Clean."
