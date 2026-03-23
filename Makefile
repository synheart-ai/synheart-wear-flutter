GARMIN_REPO := git@github.com:synheart-ai/synheart-wear-garmin-companion.git
GARMIN_SUBDIR := dart

.PHONY: build build-with-garmin build-without-garmin check-garmin fetch-garmin link-garmin clean-garmin

# Auto-detect: build with Garmin RTS if you have access, otherwise without
build:
	@if git ls-remote $(GARMIN_REPO) HEAD >/dev/null 2>&1; then \
		echo "✓ Garmin companion repo access detected"; \
		$(MAKE) build-with-garmin; \
	else \
		echo "○ No Garmin companion access — building without RTS"; \
		$(MAKE) build-without-garmin; \
	fi

# Explicit targets
build-with-garmin: fetch-garmin link-garmin
	@echo "Building Dart SDK with Garmin RTS support..."

build-without-garmin: clean-garmin
	@echo "Building Dart SDK without Garmin RTS..."

# Check repo access
check-garmin:
	@git ls-remote $(GARMIN_REPO) HEAD >/dev/null 2>&1 \
		&& echo "✓ Access OK" \
		|| (echo "✗ No access to $(GARMIN_REPO)" && exit 1)

# Clone or pull companion repo into .garmin/
fetch-garmin: check-garmin
	@if [ ! -d ".garmin" ]; then \
		echo "Cloning companion into .garmin/ ..."; \
		git clone --depth 1 $(GARMIN_REPO) .garmin; \
	else \
		echo "Updating .garmin/ ..."; \
		git -C .garmin pull --ff-only; \
	fi

# Symlink companion files into source tree
link-garmin:
	@echo "Linking Dart Garmin RTS files..."
	@# Overlay real garmin_health.dart (replaces stub)
	@ln -sf $$(pwd)/.garmin/$(GARMIN_SUBDIR)/lib/src/adapters/garmin/garmin_health.dart \
		lib/src/adapters/garmin/garmin_health.dart
	@# Link additional adapter files
	@for f in garmin_sdk_adapter.dart garmin_platform_channel.dart garmin_device_manager.dart garmin_errors.dart; do \
		ln -sf $$(pwd)/.garmin/$(GARMIN_SUBDIR)/lib/src/adapters/garmin/$$f \
			lib/src/adapters/garmin/$$f; \
	done
	@# Link model files
	@for f in garmin_device.dart garmin_connection_state.dart garmin_realtime_data.dart \
		garmin_wellness_data.dart garmin_sleep_data.dart garmin_activity_data.dart; do \
		ln -sf $$(pwd)/.garmin/$(GARMIN_SUBDIR)/lib/src/models/$$f \
			lib/src/models/$$f; \
	done
	@# Link Android native bridges
	@mkdir -p android/src/main/kotlin/com/synheart/wear/garmin
	@for f in GarminSDKBridge.kt GarminSdkWrapper.kt GarminHealthSdkWrapper.kt; do \
		ln -sf $$(pwd)/.garmin/$(GARMIN_SUBDIR)/android/src/main/kotlin/com/synheart/wear/garmin/$$f \
			android/src/main/kotlin/com/synheart/wear/garmin/$$f; \
	done
	@echo "✓ Garmin RTS files linked"

# Remove symlinks and .garmin/ directory
clean-garmin:
	@rm -rf .garmin
	@# Remove symlinks (they become dangling after .garmin/ removal)
	@find lib/src/adapters/garmin/ -type l -delete 2>/dev/null || true
	@find lib/src/models/ -name 'garmin_*' -type l -delete 2>/dev/null || true
	@find android/src/main/kotlin/com/synheart/wear/garmin/ -type l -delete 2>/dev/null || true
	@echo "✓ Garmin RTS files cleaned"
