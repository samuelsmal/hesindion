PROJECT = Hesindion.xcodeproj
SCHEME = Hesindion
SDK = iphonesimulator
CONFIG = Debug
DEVICE_NAME = iPhone 17 Pro
IPAD_NAME = iPad Pro 11-inch (M5)
DERIVED_DATA = .build
BUNDLE_ID = org.savoba.Hesindion

SAMPLE_HEROS = docs/sample_heros

# Optolith source data the rules database is built from (not in this repo).
DSA_DATA ?= ../../dsa_companion_data/Data
RULES_DB = Hesindion/Resources/rules.db

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

.PHONY: build boot install launch run build-iphone boot-iphone install-iphone launch-iphone run-iphone clean share-heros share-heros-ipad deploy deploy-ipad deploy-kombucha test test-ui test-ui-record test-ui-record-only screenshots rules-db test-rules-db rules-review rules-sweep rules-queue rules-agent test-rules-review test-rulec rules-check rules-json test-rules-engine rules-engine-fixture

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

# The build script's own tests (validate, snapshot, import). Pure Python, seconds.
test-rules-db:
	python3 -m unittest discover -s scripts/build_rules_db -p 'test_*.py' -v

# Rebuild the bundled rules database from the Optolith YAML and the rules
# catalog. Fails on a catalog problem (including a clause outside
# specs/data/rule-vocabulary.json) or when the status counts drift from
# specs/data/rules-catalog.snapshot.json; any non-empty UPDATE_SNAPSHOT value
# rewrites the snapshot. The script builds to a temp file and renames on
# success, so a failed build leaves the old database in place.
rules-db: test-rules-db
	python3 scripts/build_rules_db/build_db.py \
		--source '$(DSA_DATA)' \
		--catalog specs/data/rules-catalog.yaml \
		--snapshot specs/data/rules-catalog.snapshot.json \
		--repo-root . \
		--vocabulary specs/data/rule-vocabulary.json \
		$(if $(UPDATE_SNAPSHOT),--update-snapshot,) \
		--output '$(RULES_DB)'

# The rules rework's draft rule files (docs/rules-rework/examples/). uv installs
# the scripts' own dependencies (Textual, PyYAML) from their inline metadata.
RULES_EXAMPLES = docs/rules-rework/examples

# Review TUI: answer rulings, mark rules reviewed, send them back to the agent.
# Signs with your gh login; BY=@handle signs as someone else. SWEEP=boronmir shows only the
# rules that affect one hero ($(RULES_EXAMPLES)/sweeps/).
rules-review:
	uv run $(RULES_EXAMPLES)/review.py $(if $(BY),--by $(BY),) $(if $(SWEEP),--sweep $(SWEEP),)

# A sweep's rules and what each still needs, as text: make rules-sweep SWEEP=boronmir
rules-sweep:
	uv run $(RULES_EXAMPLES)/review.py --sweep $(SWEEP) --list

# What waits for an agent: flagged rules and answered rulings to process.
rules-queue:
	uv run $(RULES_EXAMPLES)/review.py --queue

# Start Claude Code on that queue. Interactive, so you can watch and steer; it
# does not commit.
rules-agent:
	claude "Do the agent pass on the draft rule files: run \`make rules-queue\` and work \
	through every item as $(RULES_EXAMPLES)/README.md, section 'What waits for an agent', \
	says. Finish with \`make test-rules-review\`. Do not commit."

# The review tool's file edits, and RULINGS.md current with the rule files.
test-rules-review:
	uv run --with pyyaml python -m unittest discover -s $(RULES_EXAMPLES) -p 'test_*.py' -v
	uv run --with pyyaml python $(RULES_EXAMPLES)/rulings.py --check

# The new rule format's compiler (docs/plans/2026-09-24-rules-engine-design.md). Validates the
# rule and situation files against specs/rules/vocabulary.json and compiles them to JSON for
# the Swift engine (Packages/RulesEngine).
RULEC = cd scripts && uv run --with pyyaml python -m rulec

# test_draft_fixture.py also reads build/rules/drafts/ (every passing situation's log draft and
# its compiled object), which `make test-rules-engine` writes: run the engine tests first to
# check that rulec re-imports them. Without the drafts that test skips and says so.
test-rulec:
	uv run --with pyyaml --with ruamel.yaml python -m unittest discover -s scripts/rulec -t scripts -p 'test_*.py' -v

rules-check:
	$(RULEC) check

rules-json:
	$(RULEC) build --out ../build/rules

# The new rules engine (Packages/RulesEngine): pure Swift, runs on macOS without a simulator.
# The situations harness (SituationsHarnessTests) runs the situations files RULES_FILES names:
# `make test-rules-engine RULES_FILES=kampfwerte,lebensenergie`; unset (the default) or
# `RULES_FILES=all` runs every file, `RULES_FILES=none` skips it. It writes
# build/rules/harness-report.json.
test-rules-engine: rules-json
	RULES_FILES=$(RULES_FILES) swift test --package-path Packages/RulesEngine

# The engine tests' hand-made books: the rule files in Packages/RulesEngine/Tests/FixtureRules/mini
# .../pipeline, .../actions, .../checks, .../state, .../melee and .../sheet, compiled by rulec into Tests/RulesEngineTests/Fixtures/mini-rules.json,
# pipeline-rules.json, actions-rules.json, checks-rules.json, state-rules.json, melee-rules.json and sheet-rules.json. Rerun after a change to those files or to rulec's output
# shape, and commit the JSON.
RULES_ENGINE_FIXTURE = Packages/RulesEngine/Tests/RulesEngineTests/Fixtures
rules-engine-fixture:
	mkdir -p $(RULES_ENGINE_FIXTURE)
	$(RULEC) build --rules ../Packages/RulesEngine/Tests/FixtureRules/mini --out ../build/rules-engine-fixture/mini
	cp build/rules-engine-fixture/mini/rules.json $(RULES_ENGINE_FIXTURE)/mini-rules.json
	$(RULEC) build --rules ../Packages/RulesEngine/Tests/FixtureRules/pipeline --out ../build/rules-engine-fixture/pipeline
	cp build/rules-engine-fixture/pipeline/rules.json $(RULES_ENGINE_FIXTURE)/pipeline-rules.json
	$(RULEC) build --rules ../Packages/RulesEngine/Tests/FixtureRules/actions --out ../build/rules-engine-fixture/actions
	cp build/rules-engine-fixture/actions/rules.json $(RULES_ENGINE_FIXTURE)/actions-rules.json
	$(RULEC) build --rules ../Packages/RulesEngine/Tests/FixtureRules/checks --out ../build/rules-engine-fixture/checks
	cp build/rules-engine-fixture/checks/rules.json $(RULES_ENGINE_FIXTURE)/checks-rules.json
	$(RULEC) build --rules ../Packages/RulesEngine/Tests/FixtureRules/state --out ../build/rules-engine-fixture/state
	cp build/rules-engine-fixture/state/rules.json $(RULES_ENGINE_FIXTURE)/state-rules.json
	$(RULEC) build --rules ../Packages/RulesEngine/Tests/FixtureRules/melee --out ../build/rules-engine-fixture/melee
	cp build/rules-engine-fixture/melee/rules.json $(RULES_ENGINE_FIXTURE)/melee-rules.json
	$(RULEC) build --rules ../Packages/RulesEngine/Tests/FixtureRules/sheet --out ../build/rules-engine-fixture/sheet
	cp build/rules-engine-fixture/sheet/rules.json $(RULES_ENGINE_FIXTURE)/sheet-rules.json

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

# Re-record only a specific test (class or method) — narrows the blast radius of
# a re-record so unrelated baselines aren't rewritten.
#   make test-ui-record-only ONLY=HesindionTests/SomeSnapshotTests
test-ui-record-only: boot
	TEST_RUNNER_SNAPSHOT_TESTING_RECORD=all xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-sdk $(SDK) \
		-configuration $(CONFIG) \
		-derivedDataPath $(DERIVED_DATA) \
		-destination 'platform=iOS Simulator,name=$(IPAD_NAME)' \
		$(NO_CLONE) \
		test -only-testing:$(ONLY)

# ── Screenshots ──────────────────────────────────────────────────────────────

# Runs the XCUITest target and exports its screenshot attachments to
# docs/screenshots/. Same single-simulator flags as the other test targets.
#
# xcresulttool names exported files by attachment payload, so the manifest is
# used to rename them back to the XCTAttachment names the tests set
# (01-hero-list … 20-critical-hit-table).
SCREENSHOT_DIR = docs/screenshots
SCREENSHOT_RESULT = $(DERIVED_DATA)/screenshots.xcresult
SCREENSHOT_EXPORT = $(DERIVED_DATA)/screenshot-export

screenshots: boot
	rm -rf '$(SCREENSHOT_RESULT)' '$(SCREENSHOT_EXPORT)'
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-sdk $(SDK) \
		-configuration $(CONFIG) \
		-derivedDataPath $(DERIVED_DATA) \
		-destination 'platform=iOS Simulator,name=$(IPAD_NAME)' \
		-resultBundlePath '$(SCREENSHOT_RESULT)' \
		$(NO_CLONE) \
		test -only-testing:HesindionUITests
	xcrun xcresulttool export attachments \
		--path '$(SCREENSHOT_RESULT)' \
		--output-path '$(SCREENSHOT_EXPORT)'
	@mkdir -p $(SCREENSHOT_DIR)
	@python3 scripts/export_screenshots.py '$(SCREENSHOT_EXPORT)' '$(SCREENSHOT_DIR)'
