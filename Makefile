GARMIN_REPO    := git@github.com:synheart-ai/synheart-wear-garmin-companion.git
GARMIN_SUBDIR  := dart

# The two open-source stubs that the companion overlay symlinks on top of.
# We back these up before linking and restore them on `clean-garmin`, so the
# tracked stub is never lost.
PROTECTED_STUBS := \
  lib/src/adapters/garmin/garmin_health.dart \
  android/src/main/kotlin/ai/synheart/wear/garmin/GarminSDKBridge.kt

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
# IMPORTANT: for each PROTECTED_STUB, we save the tracked stub to
# `<path>.stub` BEFORE replacing it with a symlink. `clean-garmin` restores
# from the backup. This way the tracked-in-git stub is never lost, even if
# `.garmin/` disappears unexpectedly.
link-garmin:
	@echo "Linking Dart Garmin RTS files..."
	@# Backup + replace the two protected stubs.
	@for path in $(PROTECTED_STUBS); do \
		if [ -f "$$path" ] && [ ! -L "$$path" ] && [ ! -f "$$path.stub" ]; then \
			cp "$$path" "$$path.stub"; \
		fi; \
	done
	@# Overlay garmin_health.dart (one of the protected stubs)
	@ln -sf $$(pwd)/.garmin/$(GARMIN_SUBDIR)/lib/src/adapters/garmin/garmin_health.dart \
		lib/src/adapters/garmin/garmin_health.dart
	@# Link additional adapter files (not tracked in OSS)
	@for f in garmin_sdk_adapter.dart garmin_platform_channel.dart garmin_device_manager.dart garmin_errors.dart; do \
		ln -sf $$(pwd)/.garmin/$(GARMIN_SUBDIR)/lib/src/adapters/garmin/$$f \
			lib/src/adapters/garmin/$$f; \
	done
	@# Link model files (not tracked in OSS)
	@for f in garmin_device.dart garmin_connection_state.dart garmin_realtime_data.dart \
		garmin_wellness_data.dart garmin_sleep_data.dart garmin_activity_data.dart; do \
		ln -sf $$(pwd)/.garmin/$(GARMIN_SUBDIR)/lib/src/models/$$f \
			lib/src/models/$$f; \
	done
	@# Link Android native bridges (GarminSDKBridge.kt is the second protected stub)
	@mkdir -p android/src/main/kotlin/ai/synheart/wear/garmin
	@for f in GarminSDKBridge.kt GarminSdkWrapper.kt GarminHealthSdkWrapper.kt; do \
		ln -sf $$(pwd)/.garmin/$(GARMIN_SUBDIR)/android/src/main/kotlin/ai/synheart/wear/garmin/$$f \
			android/src/main/kotlin/ai/synheart/wear/garmin/$$f; \
	done
	@echo "✓ Garmin RTS files linked"
	@echo "  (the pre-commit hook will block accidental staging of overlay symlinks)"

# Remove symlinks, the .garmin clone, AND restore the tracked stubs.
clean-garmin:
	@rm -rf .garmin
	@# Remove overlay symlinks (they become dangling after .garmin/ removal)
	@find lib/src/adapters/garmin/ -type l -delete 2>/dev/null || true
	@find lib/src/models/ -name 'garmin_*' -type l -delete 2>/dev/null || true
	@find android/src/main/kotlin/ai/synheart/wear/garmin/ -type l -delete 2>/dev/null || true
	@# Restore the protected stubs from backup if missing.
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
# stub paths. Intended for CI.
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
