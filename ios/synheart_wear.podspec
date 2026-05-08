Pod::Spec.new do |s|
  s.name             = 'synheart_wear'
  s.version          = '0.4.0'
  s.summary          = 'Unified wearable SDK for Synheart (iOS plugin)'
  s.description      = <<-DESC
Synheart Wear iOS plugin for HealthKit heartbeat series (RR) integration
and optional Garmin Companion SDK integration.
  DESC
  s.homepage         = 'https://github.com/synheart-ai/synheart_wear'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Synheart' => 'opensource@synheart.ai' }
  s.source           = { :path => '.' }

  # Only Swift/Obj-C sources — markdown READMEs inside `Classes/Garmin/Impl/`
  # (the gitignored overlay target dir) would otherwise be dragged into the
  # Copy Resources phase and emit "no rule to process file" warnings for
  # every build.
  s.source_files = 'Classes/**/*.{swift,h,m}'
  s.dependency 'Flutter'
  s.platform = :ios, '16.0'
  s.swift_version = '5.10'
  s.static_framework = true

  # ============================================================================
  # GARMIN SDK INTEGRATION (Optional)
  # ============================================================================
  #
  # The Garmin Companion SDK requires a license from Garmin Health.
  # If you have a license, follow these steps:
  #
  # 1. Download the Garmin Companion SDK XCFramework from your
  #    Garmin Health SDK distribution channel.
  #
  # 2. Extract Companion.xcframework and copy it to:
  #    <your_app>/ios/.symlinks/plugins/synheart_wear/ios/Frameworks/
  #    OR
  #    <plugin_path>/ios/Frameworks/Companion.xcframework
  #
  # 3. Uncomment the vendored_frameworks line below
  #
  # Without the SDK, Garmin methods will return "SDK not available" errors.
  # ============================================================================

  # Uncomment after adding Companion.xcframework to ios/Frameworks/
  # s.vendored_frameworks = 'Frameworks/Companion.xcframework'

  # Weak linking allows app to run if SDK framework is not present at runtime
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    # Uncomment when SDK is present to enable weak linking
    # 'OTHER_LDFLAGS' => '-weak_framework Companion',
  }

  # Required frameworks for HealthKit
  s.frameworks = 'HealthKit'
end
