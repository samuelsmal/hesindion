PROJECT = iDSACompanion.xcodeproj
SCHEME = iDSACompanion
SDK = iphonesimulator
CONFIG = Debug
DEVICE_NAME = iPhone 17 Pro
DERIVED_DATA = .build
BUNDLE_ID = org.savoba.iDSACompanion

SAMPLE_HEROS = docs/sample_heros

DEVICE_ID = $(shell xcrun simctl list devices available | grep '$(DEVICE_NAME)' | head -1 | sed 's/.*(\([A-F0-9-]*\)).*/\1/')
APP_PATH = $(DERIVED_DATA)/Build/Products/$(CONFIG)-iphonesimulator/$(SCHEME).app
APP_DATA = $(shell xcrun simctl get_app_container '$(DEVICE_ID)' $(BUNDLE_ID) data 2>/dev/null)

.PHONY: build boot install launch run clean share-heros

build:
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-sdk $(SDK) \
		-configuration $(CONFIG) \
		-derivedDataPath $(DERIVED_DATA) \
		-destination 'platform=iOS Simulator,name=$(DEVICE_NAME)' \
		build

boot:
	xcrun simctl boot '$(DEVICE_ID)' 2>/dev/null || true
	open -a Simulator

install: build boot
	xcrun simctl install '$(DEVICE_ID)' '$(APP_PATH)'

launch:
	xcrun simctl launch '$(DEVICE_ID)' $(BUNDLE_ID)

run: install launch

share-heros: boot
	@if [ -z "$(APP_DATA)" ]; then \
		echo "Error: App not installed. Run 'make install' first."; \
		exit 1; \
	fi
	@mkdir -p "$(APP_DATA)/Documents"
	cp "$(SAMPLE_HEROS)/"*.json "$(APP_DATA)/Documents/"
	@echo "Copied sample heros to $(APP_DATA)/Documents/"

clean:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -sdk $(SDK) clean
	rm -rf $(DERIVED_DATA)
