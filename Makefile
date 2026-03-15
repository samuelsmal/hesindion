PROJECT = Hesindion.xcodeproj
SCHEME = Hesindion
SDK = iphonesimulator
CONFIG = Debug
DEVICE_NAME = iPhone 17 Pro
IPAD_NAME = iPad Pro 11-inch (M5)
DERIVED_DATA = .build
BUNDLE_ID = org.savoba.Hesindion

SAMPLE_HEROS = docs/sample_heros

# Physical devices
PHYSICAL_DEVICE_NAME = Karl
PHYSICAL_DEVICE_ID = $(shell xcrun devicectl list devices 2>/dev/null | grep '$(PHYSICAL_DEVICE_NAME)' | awk '{print $$3}')
KOMBUCHA_DEVICE_ID = $(shell xcrun devicectl list devices 2>/dev/null | grep 'Kombucha' | awk '{print $$3}')

# Simulator
DEVICE_ID = $(shell xcrun simctl list devices available | grep '$(DEVICE_NAME)' | head -1 | sed 's/.*(\([A-F0-9-]*\)).*/\1/')
IPAD_ID = $(shell xcrun simctl list devices available | grep '$(IPAD_NAME)' | head -1 | sed 's/.*(\([A-F0-9-]*\)).*/\1/')
APP_PATH = $(DERIVED_DATA)/Build/Products/$(CONFIG)-iphonesimulator/$(SCHEME).app
APP_DATA = $(shell xcrun simctl get_app_container '$(DEVICE_ID)' $(BUNDLE_ID) data 2>/dev/null)
IPAD_APP_DATA = $(shell xcrun simctl get_app_container '$(IPAD_ID)' $(BUNDLE_ID) data 2>/dev/null)

.PHONY: build boot install launch run build-ipad boot-ipad install-ipad launch-ipad run-ipad clean share-heros share-heros-ipad deploy deploy-ipad deploy-kombucha

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

build-ipad:
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-sdk $(SDK) \
		-configuration $(CONFIG) \
		-derivedDataPath $(DERIVED_DATA) \
		-destination 'platform=iOS Simulator,name=$(IPAD_NAME)' \
		build

boot-ipad:
	xcrun simctl boot '$(IPAD_ID)' 2>/dev/null || true
	open -a Simulator

install-ipad: build-ipad boot-ipad
	xcrun simctl install '$(IPAD_ID)' '$(APP_PATH)'

launch-ipad:
	xcrun simctl launch '$(IPAD_ID)' $(BUNDLE_ID) $(LAUNCH_ARGS)

run-ipad: install-ipad launch-ipad

# Debug shortcut: make debug-combat → builds, launches iPad with first hero in combat view
debug-combat: LAUNCH_ARGS = debug load_default path combat
debug-combat: run-ipad

share-heros: boot
	@if [ -z "$(APP_DATA)" ]; then \
		echo "Error: App not installed. Run 'make install' first."; \
		exit 1; \
	fi
	@mkdir -p "$(APP_DATA)/Documents"
	cp "$(SAMPLE_HEROS)/"*.json "$(APP_DATA)/Documents/"
	@echo "Copied sample heros to $(APP_DATA)/Documents/"

share-heros-ipad:
	xcrun simctl boot '$(IPAD_ID)' 2>/dev/null || true
	open -a Simulator
	@if [ -z "$(IPAD_APP_DATA)" ]; then \
		echo "Error: App not installed on iPad. Install it first."; \
		exit 1; \
	fi
	@mkdir -p "$(IPAD_APP_DATA)/Documents"
	cp "$(SAMPLE_HEROS)/"*.json "$(IPAD_APP_DATA)/Documents/"
	@echo "Copied sample heros to iPad: $(IPAD_APP_DATA)/Documents/"

deploy:
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIG) \
		-derivedDataPath $(DERIVED_DATA) \
		-destination 'platform=iOS,name=$(PHYSICAL_DEVICE_NAME)' \
		build
	xcrun devicectl device install app --device '$(PHYSICAL_DEVICE_ID)' '$(DERIVED_DATA)/Build/Products/$(CONFIG)-iphoneos/$(SCHEME).app'
	xcrun devicectl device process launch --device '$(PHYSICAL_DEVICE_ID)' $(BUNDLE_ID)

deploy-ipad: deploy-kombucha

deploy-kombucha:
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIG) \
		-derivedDataPath $(DERIVED_DATA) \
		-destination 'platform=iOS,name=Kombucha' \
		build
	xcrun devicectl device install app --device '$(KOMBUCHA_DEVICE_ID)' '$(DERIVED_DATA)/Build/Products/$(CONFIG)-iphoneos/$(SCHEME).app'
	xcrun devicectl device process launch --device '$(KOMBUCHA_DEVICE_ID)' $(BUNDLE_ID)

clean:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -sdk $(SDK) clean
	rm -rf $(DERIVED_DATA)
