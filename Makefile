GARMIN_REPO    := git@github.com:synheart-ai/synheart-wear-garmin-companion.git
GARMIN_SUBDIR  := dart

# The single tracked OSS file that the companion overlay symlinks on top of.
# `link-garmin` backs it up to `<path>.stub` before linking; `clean-garmin`
# restores it. Everything else the overlay supplies (the licensed
# `Garmin*Wrapper.kt` Kotlin files) is gitignored, so a mistaken `git add -A`
# can't even see them.
PROTECTED_STUBS := \
  android/src/main/kotlin/ai/synheart/wear/garmin/GarminSDKBridge.kt

# Companion-only Kotlin files. These are NOT tracked in OSS; the overlay
# drops them into place during `link-garmin`.
COMPANION_KOTLIN := \
  GarminSdkWrapper.kt \
  GarminHealthSdkWrapper.kt

.PHONY: build build-with-garmin build-without-garmin \
        check-garmin fetch-garmin link-garmin clean-garmin \
        install-hooks verify-clean

# ---------------------------------------------------------------------------
# Top-level build entrypoint
# ---------------------------------------------------------------------------
# Auto-detect: build with Garmin RTS if the developer has companion access,
# otherwise fall back to stub mode. Always installs the safety hooks first.
build: install-hooks
	@if git ls-remote $(GARMIN_REPO) HEAD >/dev/null 2>&1; then \
		echo "✓ Garmin companion repo access detected"; \
		$(MAKE) build-with-garmin; \
	else \
		echo "○ No Garmin companion access — building without RTS"; \
		$(MAKE) build-without-garmin; \
	fi

build-with-garmin: install-hooks fetch-garmin link-garmin
	@echo "Building Dart SDK with Garmin RTS support..."

build-without-garmin: install-hooks clean-garmin
	@echo "Building Dart SDK without Garmin RTS..."

# ---------------------------------------------------------------------------
# Companion repo plumbing
# ---------------------------------------------------------------------------
check-garmin:
	@git ls-remote $(GARMIN_REPO) HEAD >/dev/null 2>&1 \
		&& echo "✓ Access OK" \
		|| (echo "✗ No access to $(GARMIN_REPO)" && exit 1)

fetch-garmin: check-garmin
	@if [ ! -d ".garmin" ]; then \
		echo "Cloning companion into .garmin/ ..."; \
		git clone --depth 1 $(GARMIN_REPO) .garmin; \
	else \
		echo "Updating .garmin/ ..."; \
		git -C .garmin pull --ff-only; \
	fi

# Overlay the licensed companion files on top of the open-source tree.
#
# As of the dart-out-of-companion refactor, only the native native wrapper(s)
# live in the companion repo. All Dart code (adapters, models, errors) is
# OSS, so the overlay no longer touches `lib/`.
#
# Android: Kotlin wrappers + the protected GarminSDKBridge.kt stub.
# iOS: the GarminSDKBridgeImpl.swift implementation, dropped into the
#      gitignored `ios/Classes/Garmin/Impl/` directory. The OSS iOS
#      GarminSDKBridge.swift stub stays untouched and looks the impl up
#      at runtime via NSClassFromString.
#
# IMPORTANT: for each PROTECTED_STUB, we save the tracked OSS file to
# `<path>.stub` BEFORE replacing it with a symlink. `clean-garmin` restores
# from the backup. This way the tracked-in-git stub is never lost, even if
# `.garmin/` disappears unexpectedly.
link-garmin:
	@echo "Linking Garmin RTS files..."
	@# Backup the protected OSS stub.
	@for path in $(PROTECTED_STUBS); do \
		if [ -f "$$path" ] && [ ! -L "$$path" ] && [ ! -f "$$path.stub" ]; then \
			cp "$$path" "$$path.stub"; \
		fi; \
	done
	@# Overlay the protected Kotlin stub.
	@ln -sf $$(pwd)/.garmin/$(GARMIN_SUBDIR)/android/src/main/kotlin/ai/synheart/wear/garmin/GarminSDKBridge.kt \
		android/src/main/kotlin/ai/synheart/wear/garmin/GarminSDKBridge.kt
	@# Link companion-only Kotlin wrappers (gitignored — never tracked in OSS).
	@mkdir -p android/src/main/kotlin/ai/synheart/wear/garmin
	@for f in $(COMPANION_KOTLIN); do \
		ln -sf $$(pwd)/.garmin/$(GARMIN_SUBDIR)/android/src/main/kotlin/ai/synheart/wear/garmin/$$f \
			android/src/main/kotlin/ai/synheart/wear/garmin/$$f; \
	done
	@# iOS overlay — symlink the licensed impl into the gitignored Impl/
	@# directory. No tracked stub to protect: Impl/*.swift is gitignored.
	@mkdir -p ios/Classes/Garmin/Impl
	@if [ -f .garmin/$(GARMIN_SUBDIR)/ios/Classes/Garmin/GarminSDKBridgeImpl.swift ]; then \
		ln -sf $$(pwd)/.garmin/$(GARMIN_SUBDIR)/ios/Classes/Garmin/GarminSDKBridgeImpl.swift \
			ios/Classes/Garmin/Impl/GarminSDKBridgeImpl.swift; \
	else \
		echo "  ○ .garmin/$(GARMIN_SUBDIR)/ios/Classes/Garmin/GarminSDKBridgeImpl.swift not found — iOS overlay skipped"; \
		echo "    (update the companion repo or set GARMIN_BRANCH= to a branch that includes it)"; \
	fi
	@echo "✓ Garmin RTS files linked"
	@echo "  (the pre-commit hook will block accidental staging of overlay symlinks)"

# Remove symlinks, the .garmin clone, AND restore the tracked stub.
clean-garmin:
	@rm -rf .garmin
	@# Remove Android overlay symlinks (dangling after .garmin/ removal).
	@find android/src/main/kotlin/ai/synheart/wear/garmin/ -type l -delete 2>/dev/null || true
	@# Remove iOS overlay symlinks (dangling after .garmin/ removal).
	@find ios/Classes/Garmin/Impl/ -type l -delete 2>/dev/null || true
	@# Restore the protected stub from backup if missing.
	@for path in $(PROTECTED_STUBS); do \
		if [ -f "$$path.stub" ] && [ ! -e "$$path" ]; then \
			mv "$$path.stub" "$$path"; \
			echo "  restored $$path"; \
		elif [ -f "$$path.stub" ]; then \
			rm -f "$$path.stub"; \
		fi; \
	done
	@echo "✓ Garmin RTS files cleaned"

# ---------------------------------------------------------------------------
# Safety hooks
# ---------------------------------------------------------------------------
# Configure git to use the in-repo .githooks/ directory. Idempotent.
install-hooks:
	@current="$$(git config --local --get core.hooksPath || true)"; \
	if [ "$$current" != ".githooks" ]; then \
		git config --local core.hooksPath .githooks; \
		echo "✓ git core.hooksPath → .githooks"; \
	fi

# Fail loudly if the working tree contains overlay symlinks at the protected
# stub path. Intended for CI.
verify-clean:
	@fail=0; \
	for path in $(PROTECTED_STUBS); do \
		if [ -L "$$path" ]; then \
			echo "✗ $$path is a symlink (overlay leaked into the working tree)"; \
			fail=1; \
		fi; \
	done; \
	if [ $$fail -ne 0 ]; then \
		echo; \
		echo "Run \`make clean-garmin\` and try again."; \
		exit 1; \
	fi; \
	echo "✓ No Garmin overlay symlinks in protected paths"
