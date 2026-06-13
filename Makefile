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

.PHONY: build boot install launch run build-iphone boot-iphone install-iphone launch-iphone run-iphone clean share-heros share-heros-ipad deploy deploy-ipad deploy-kombucha test test-ui test-ui-record

build:
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-sdk $(SDK) \
		-configuration $(CONFIG) \
		-derivedDataPath $(DERIVED_DATA) \
		-destination 'platform=iOS Simulator,name=$(IPAD_NAME)' \
		build

boot:
	xcrun simctl boot '$(IPAD_ID)' 2>/dev/null || true
	open -a Simulator

install: build boot
	xcrun simctl install '$(IPAD_ID)' '$(APP_PATH)'

launch:
	xcrun simctl launch '$(IPAD_ID)' $(BUNDLE_ID) $(LAUNCH_ARGS)

run: install launch

build-iphone:
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-sdk $(SDK) \
		-configuration $(CONFIG) \
		-derivedDataPath $(DERIVED_DATA) \
		-destination 'platform=iOS Simulator,name=$(DEVICE_NAME)' \
		build

boot-iphone:
	xcrun simctl boot '$(DEVICE_ID)' 2>/dev/null || true
	open -a Simulator

install-iphone: build-iphone boot-iphone
	xcrun simctl install '$(DEVICE_ID)' '$(APP_PATH)'

launch-iphone:
	xcrun simctl launch '$(DEVICE_ID)' $(BUNDLE_ID)

run-iphone: install-iphone launch-iphone

# Debug shortcut: make debug-combat → builds, launches iPad with first hero in combat view
debug-combat: LAUNCH_ARGS = debug load_default path combat
debug-combat: run

share-heros: boot
	@if [ -z "$(IPAD_APP_DATA)" ]; then \
		echo "Error: App not installed. Run 'make install' first."; \
		exit 1; \
	fi
	@mkdir -p "$(IPAD_APP_DATA)/Documents"
	cp "$(SAMPLE_HEROS)/"*.json "$(IPAD_APP_DATA)/Documents/"
	@echo "Copied sample heros to $(IPAD_APP_DATA)/Documents/"

share-heros-iphone: boot-iphone
	@if [ -z "$(APP_DATA)" ]; then \
		echo "Error: App not installed on iPhone. Install it first."; \
		exit 1; \
	fi
	@mkdir -p "$(APP_DATA)/Documents"
	cp "$(SAMPLE_HEROS)/"*.json "$(APP_DATA)/Documents/"
	@echo "Copied sample heros to iPhone: $(APP_DATA)/Documents/"

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

# ── Testing ──────────────────────────────────────────────────────────────────

# Force xcodebuild onto the single named simulator. Without these, test
# parallelization clones the device (one booting sim per worker → several
# simulators on the boot screen at once). NO clones, NO extra boots.
NO_CLONE = -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1

test: boot
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-sdk $(SDK) \
		-configuration $(CONFIG) \
		-derivedDataPath $(DERIVED_DATA) \
		-destination 'platform=iOS Simulator,name=$(IPAD_NAME)' \
		$(NO_CLONE) \
		test

test-ui: boot
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-sdk $(SDK) \
		-configuration $(CONFIG) \
		-derivedDataPath $(DERIVED_DATA) \
		-destination 'platform=iOS Simulator,name=$(IPAD_NAME)' \
		$(NO_CLONE) \
		test -only-testing:HesindionTests

# Re-record snapshot baselines. swift-snapshot-testing reads
# SNAPSHOT_TESTING_RECORD from the test *runner* process, so the value must be
# injected with the TEST_RUNNER_ prefix (xcodebuild strips it before launch);
# a plain host env var never reaches the simulator process. Valid values are
# all/failed/missing/never — "all" force-records every snapshot.
test-ui-record: boot
	TEST_RUNNER_SNAPSHOT_TESTING_RECORD=all xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-sdk $(SDK) \
		-configuration $(CONFIG) \
		-derivedDataPath $(DERIVED_DATA) \
		-destination 'platform=iOS Simulator,name=$(IPAD_NAME)' \
		$(NO_CLONE) \
		test -only-testing:HesindionTests
