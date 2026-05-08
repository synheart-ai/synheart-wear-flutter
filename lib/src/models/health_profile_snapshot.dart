/// Biological sex as reported by the platform health store.
///
/// Maps from `HKBiologicalSex` on iOS (`female`/`male`/`other`/`notSet`) and
/// from Health Connect's lack of a sex characteristic on Android (always
/// returns `null`).
enum HealthBiologicalSex { female, male, other }

/// Snapshot of demographic and anthropometric values pulled from the device's
/// native health store (Apple Health on iOS, Health Connect on Android).
///
/// All fields are optional because:
///  - the user may not have entered them in the health app
///  - the user may not have granted read permission for that type
///  - the platform may not expose that field at all (e.g. Health Connect has
///    no DOB / sex / blood type characteristics)
class HealthProfileSnapshot {
  final HealthBiologicalSex? biologicalSex;
  final DateTime? dateOfBirth;
  final String? bloodType;
  final double? heightCm;
  final double? weightKg;
  final double? bodyFatPercent;

  const HealthProfileSnapshot({
    this.biologicalSex,
    this.dateOfBirth,
    this.bloodType,
    this.heightCm,
    this.weightKg,
    this.bodyFatPercent,
  });

  static const HealthProfileSnapshot empty = HealthProfileSnapshot();

  bool get isEmpty =>
      biologicalSex == null &&
      dateOfBirth == null &&
      bloodType == null &&
      heightCm == null &&
      weightKg == null &&
      bodyFatPercent == null;

  /// Decode the platform-channel payload. Each native handler returns a flat
  /// map with the keys below; missing keys are interpreted as "not available".
  factory HealthProfileSnapshot.fromMap(Map<dynamic, dynamic> map) {
    HealthBiologicalSex? sex;
    final sexRaw = map['biologicalSex'] as String?;
    switch (sexRaw) {
      case 'female':
        sex = HealthBiologicalSex.female;
      case 'male':
        sex = HealthBiologicalSex.male;
      case 'other':
        sex = HealthBiologicalSex.other;
    }

    DateTime? dob;
    final dobRaw = map['dateOfBirth'] as String?;
    if (dobRaw != null && dobRaw.isNotEmpty) {
      dob = DateTime.tryParse(dobRaw);
    }

    return HealthProfileSnapshot(
      biologicalSex: sex,
      dateOfBirth: dob,
      bloodType: map['bloodType'] as String?,
      heightCm: (map['heightCm'] as num?)?.toDouble(),
      weightKg: (map['weightKg'] as num?)?.toDouble(),
      bodyFatPercent: (map['bodyFatPercent'] as num?)?.toDouble(),
    );
  }
}
