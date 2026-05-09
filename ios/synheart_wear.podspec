Pod::Spec.new do |s|
  s.name             = 'synheart_wear'
  s.version          = '0.4.1'
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
  # If you have a license, drop Companion.xcframework into
  # `ios/Frameworks/Companion.xcframework` (either in this repo or in
  # `<your_app>/ios/.symlinks/plugins/synheart_wear/ios/Frameworks/`).
  # The conditional below detects it at `pod install` time and wires up
  # vendored_frameworks + weak linking automatically. OSS consumers
  # without the license skip both — `pod install` still succeeds, and
  # Garmin methods return "SDK not available" at runtime.
  # ============================================================================

  companion_xcframework = File.expand_path('Frameworks/Companion.xcframework', __dir__)
  if File.exist?(companion_xcframework)
    s.vendored_frameworks = 'Frameworks/Companion.xcframework'
    s.pod_target_xcconfig = {
      'DEFINES_MODULE' => 'YES',
      'OTHER_LDFLAGS'  => '-weak_framework Companion',
    }
  else
    s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  end

  # Required frameworks for HealthKit
  s.frameworks = 'HealthKit'
end
