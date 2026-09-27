PROJECT = Hesindion.xcodeproj
SCHEME = Hesindion
SDK = iphonesimulator
CONFIG = Debug
DEVICE_NAME = iPhone 17 Pro
IPAD_NAME = iPad Pro 11-inch (M5)
DERIVED_DATA = .build
BUNDLE_ID = org.savoba.Hesindion

SAMPLE_HEROES = specs/heroes

# Optolith source data the rules database is built from (not in this repo).
DSA_DATA ?= ../../dsa_companion_data/Data
RULES_DB = Hesindion/Resources/rules.db
RULES_JSON = Hesindion/Resources/rules.json
CHECKS_JSON = Hesindion/Resources/checks.json

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

.PHONY: build boot install launch run build-iphone boot-iphone install-iphone launch-iphone run-iphone clean share-heros share-heros-ipad deploy deploy-ipad deploy-kombucha test test-ui test-only test-ui-record test-ui-record-only screenshots rules-db test-rules-db rules-review rules-sweep rules-queue rules-agent test-rules-review test-rulec rules-check rules-json test-rules-sync rules-sync rules-coverage test-rules-engine rules-engine-fixture require-rules-db require-rules-json companions test-companions hero-sheet-fixtures

# rules.db is a build product (gitignored, not committed — decided 2026-09-23). Every target
# that ships the app depends on this and refuses to run without it; make rules-db builds it.
# The app's test targets depend on rules-db instead, so a test never runs against a stale
# database. test-rules-engine depends on neither: Packages/RulesEngine reads no rules.db.
require-rules-db:
	@if [ ! -f '$(RULES_DB)' ]; then \
		echo "rules.db missing: run make rules-db (needs DSA_DATA=…/dsa_companion_data/Data)"; \
		exit 1; \
	fi

# rules.json and checks.json are build products too (the rules engine's book and the Probe table,
# docs/plans/2026-09-27-sheet-cutover-design.md §2): gitignored, copied in by make rules-json.
require-rules-json:
	@if [ ! -f '$(RULES_JSON)' ] || [ ! -f '$(CHECKS_JSON)' ]; then \
		echo "rules.json missing: run make rules-json"; \
		exit 1; \
	fi

build: require-rules-db require-rules-json
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

build-iphone: require-rules-db require-rules-json
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
	cp "$(SAMPLE_HEROES)/"*.json "$(IPAD_APP_DATA)/Documents/"
	@echo "Copied sample heros to $(IPAD_APP_DATA)/Documents/"

share-heros-iphone: boot-iphone
	@if [ -z "$(APP_DATA)" ]; then \
		echo "Error: App not installed on iPhone. Install it first."; \
		exit 1; \
	fi
	@mkdir -p "$(APP_DATA)/Documents"
	cp "$(SAMPLE_HEROES)/"*.json "$(APP_DATA)/Documents/"
	@echo "Copied sample heros to iPhone: $(APP_DATA)/Documents/"

deploy: require-rules-db require-rules-json
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

deploy-kombucha: require-rules-db require-rules-json
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

# Companion builds (docs/plans/2026-09-24-companion-data-design.md): check
# <export>.companions.yaml against its Optolith export and inject the `hesindion`
# block. FIX=1 first sets the export's own pet fields from the build; CHECK=1
# validates without writing.
#   make companions HERO="specs/heroes/Boronmir Siebenfeld von Greifenfurt (2026-09-24).json"
companions:
	python3 scripts/companions/amend_export.py '$(HERO)' $(if $(FIX),--fix,) $(if $(CHECK),--check,)

test-companions:
	python3 -m unittest discover -s scripts/companions -p 'test_*.py' -v

# Rebuild the bundled rules database from the Optolith YAML and the rules
# catalog. Fails on a catalog problem (including a clause outside
# specs/data/rule-vocabulary.json) or when the status counts drift from
# specs/data/rules-catalog.snapshot.json; any non-empty UPDATE_SNAPSHOT value
# rewrites the snapshot. The script builds to a temp file and renames on
# success, so a failed build leaves the old database in place.
rules-db: test-rules-db
	@if [ ! -d '$(DSA_DATA)' ]; then \
		echo "DSA_DATA not found: $(DSA_DATA) (the Optolith data rules.db is built from; set DSA_DATA=…/dsa_companion_data/Data)"; \
		exit 1; \
	fi
	python3 scripts/build_rules_db/build_db.py \
		--source '$(DSA_DATA)' \
		--catalog specs/data/rules-catalog.yaml \
		--snapshot specs/data/rules-catalog.snapshot.json \
		--repo-root . \
		--vocabulary specs/data/rule-vocabulary.json \
		$(if $(UPDATE_SNAPSHOT),--update-snapshot,) \
		--output '$(RULES_DB)'

# The rule files (specs/rules/) and their review tools (scripts/rules_review/). uv installs
# the scripts' own dependencies (Textual, PyYAML) from their inline metadata.
RULES_DIR = specs/rules
RULES_REVIEW = scripts/rules_review

# Review TUI: answer rulings, mark rules reviewed, send them back to the agent.
# Signs with your gh login; BY=@handle signs as someone else. SWEEP=boronmir shows only the
# rules that affect one hero ($(RULES_DIR)/sweeps/).
rules-review:
	uv run $(RULES_REVIEW)/review.py $(if $(BY),--by $(BY),) $(if $(SWEEP),--sweep $(SWEEP),)

# A sweep's rules and what each still needs, as text: make rules-sweep SWEEP=boronmir
rules-sweep:
	uv run $(RULES_REVIEW)/review.py --sweep $(SWEEP) --list

# What waits for an agent: flagged rules and answered rulings to process.
rules-queue:
	uv run $(RULES_REVIEW)/review.py --queue

# Start Claude Code on that queue. Interactive, so you can watch and steer; it
# does not commit.
rules-agent:
	claude "Do the agent pass on the draft rule files: run \`make rules-queue\` and work \
	through every item as $(RULES_DIR)/README.md, section 'What waits for an agent', \
	says. Finish with \`make test-rules-review\`. Do not commit."

# The review tool's file edits, and RULINGS.md current with the rule files.
test-rules-review:
	uv run --with pyyaml python -m unittest discover -s $(RULES_REVIEW) -p 'test_*.py' -v
	uv run --with pyyaml python $(RULES_REVIEW)/rulings.py --check

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
	cp build/rules/rules.json $(RULES_JSON)
	cp build/rules/checks.json $(CHECKS_JSON)

# Rule-website page tracking (docs/adr/0017-rule-website-page-tracking.md).
RULES_SYNC = cd scripts && uv run --with requests --with beautifulsoup4 --with pyyaml python

test-rules-sync:
	$(RULES_SYNC) -m unittest discover -s rules_sync -t . -p 'test_*.py' -v

# Crawl every page of the rule website into specs/rules/pages.yaml (about one page a second; a
# first run takes long, a re-run the same day resumes from .cache/). MAX_AGE=0 refetches all.
# ADOPT=1 writes the page hash into every rule file that has none; ADOPT=SA_40,ADV_4 into those;
# ADOPT=0 (or unset) adopts nothing.
rules-sync:
	$(RULES_SYNC) -m rules_sync sync $(if $(MAX_AGE),--max-age-hours $(MAX_AGE),) \
		$(if $(filter 1,$(ADOPT)),--adopt,$(if $(filter-out 0,$(ADOPT)),--adopt-ids $(ADOPT),))

# How many rule-website pages are processed, per category; which rules to reprocess. Offline.
# LIST=new (or skipped, drafted, …) lists one status's pages; CHECK=1 fails on changed pages,
# rules whose page is unknown, and rules on a non-rule page (index, broken or gone).
rules-coverage:
	$(RULES_SYNC) -m rules_sync coverage $(if $(LIST),--list $(LIST),) $(if $(CHECK),--check,)

# The new rules engine (Packages/RulesEngine): pure Swift, runs on macOS without a simulator.
# The situations harness (SituationsHarnessTests) runs the situations files RULES_FILES names:
# `make test-rules-engine RULES_FILES=kampfwerte,lebensenergie`; unset (the default) or
# `RULES_FILES=all` runs every file, `RULES_FILES=none` skips it. It writes
# build/rules/harness-report.json.
# A situation with a `conflict` field that is not resolved (specs/rules/README.md, "How conflicts
# are kept") is a listed conflict, checked against its
# fingerprints in specs/rules/conflict-fingerprints.json (query, step, mismatch kind;
# ruling R78): a mismatch outside them fails, fingerprints that no longer occur are printed.
# `make test-rules-engine RECORD_CONFLICT_FINGERPRINTS=1` re-records the snapshot from the run (only
# the RULES_FILES run; other files' entries are kept); review its diff and commit it.
test-rules-engine: rules-json
	RULES_FILES=$(RULES_FILES) RECORD_CONFLICT_FINGERPRINTS=$(RECORD_CONFLICT_FINGERPRINTS) swift test --package-path Packages/RulesEngine

# hero.py's view of every sample hero, for HeroSheetMappingTests (the app's mapping must state the
# same facts). Rerun after a change to specs/heroes or scripts/rulec/hero.py, and commit the JSON.
HERO_SHEET_FIXTURES = HesindionTests/Fixtures/HeroSheets
hero-sheet-fixtures:
	cd scripts && uv run --with pyyaml python -m rulec.hero_sheet_fixtures ../specs/heroes ../$(HERO_SHEET_FIXTURES)

# The engine tests' hand-made books: the rule files in Packages/RulesEngine/Tests/FixtureRules/mini
# .../pipeline, .../actions, .../checks, .../state, .../melee, .../sheet and .../damage, compiled by rulec into Tests/RulesEngineTests/Fixtures/mini-rules.json,
# pipeline-rules.json, actions-rules.json, checks-rules.json, state-rules.json, melee-rules.json, sheet-rules.json and damage-rules.json. Rerun after a change to those files or to rulec's output
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
	$(RULEC) build --rules ../Packages/RulesEngine/Tests/FixtureRules/damage --out ../build/rules-engine-fixture/damage
	cp build/rules-engine-fixture/damage/rules.json $(RULES_ENGINE_FIXTURE)/damage-rules.json

# ── Testing ──────────────────────────────────────────────────────────────────

# Force xcodebuild onto the single named simulator. Without these, test
# parallelization clones the device (one booting sim per worker → several
# simulators on the boot screen at once). NO clones, NO extra boots.
NO_CLONE = -parallel-testing-enabled NO -maximum-concurrent-test-simulator-destinations 1

test: rules-db rules-json boot
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-sdk $(SDK) \
		-configuration $(CONFIG) \
		-derivedDataPath $(DERIVED_DATA) \
		-destination 'platform=iOS Simulator,name=$(IPAD_NAME)' \
		$(NO_CLONE) \
		test

test-ui: rules-db rules-json boot
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-sdk $(SDK) \
		-configuration $(CONFIG) \
		-derivedDataPath $(DERIVED_DATA) \
		-destination 'platform=iOS Simulator,name=$(IPAD_NAME)' \
		$(NO_CLONE) \
		test -only-testing:HesindionTests

# Run one test class or method (no re-recording):
#   make test-only ONLY=HesindionUITests/CompanionReimportFlowTests
test-only: boot
	xcodebuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-sdk $(SDK) \
		-configuration $(CONFIG) \
		-derivedDataPath $(DERIVED_DATA) \
		-destination 'platform=iOS Simulator,name=$(IPAD_NAME)' \
		$(NO_CLONE) \
		test -only-testing:$(ONLY)

# Re-record snapshot baselines. swift-snapshot-testing reads
# SNAPSHOT_TESTING_RECORD from the test *runner* process, so the value must be
# injected with the TEST_RUNNER_ prefix (xcodebuild strips it before launch);
# a plain host env var never reaches the simulator process. Valid values are
# all/failed/missing/never — "all" force-records every snapshot.
test-ui-record: rules-db rules-json boot
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
test-ui-record-only: rules-db rules-json boot
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
