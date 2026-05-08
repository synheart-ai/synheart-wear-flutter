import Flutter
import HealthKit

/// Bridges Apple Health "characteristics" (date of birth, biological sex,
/// blood type) and the latest height / weight / body-fat samples to a single
/// `synheart_wear/healthkit_profile` MethodChannel so a Flutter host can
/// prefill a user-profile form instead of asking the user to retype values
/// they already entered in the Health app.
///
/// Read-only: this handler never writes to HealthKit. Authorization for these
/// types is requested separately from the HR/RR/sleep flow because the host
/// app may want to ask for profile permission only when the user actively
/// taps a "Sync from Apple Health" button.
@available(iOS 13.0, *)
public class HealthKitProfileHandler: NSObject, FlutterPlugin {
    private let healthStore = HKHealthStore()

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "synheart_wear/healthkit_profile",
            binaryMessenger: registrar.messenger()
        )
        let instance = HealthKitProfileHandler()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isAvailable":
            result(HKHealthStore.isHealthDataAvailable())
        case "requestAuthorization":
            requestAuthorization(result: result)
        case "readProfile":
            readProfile(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Authorization

    private var profileReadTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []
        if let dob = HKObjectType.characteristicType(forIdentifier: .dateOfBirth) {
            types.insert(dob)
        }
        if let sex = HKObjectType.characteristicType(forIdentifier: .biologicalSex) {
            types.insert(sex)
        }
        if let blood = HKObjectType.characteristicType(forIdentifier: .bloodType) {
            types.insert(blood)
        }
        if let height = HKObjectType.quantityType(forIdentifier: .height) {
            types.insert(height)
        }
        if let weight = HKObjectType.quantityType(forIdentifier: .bodyMass) {
            types.insert(weight)
        }
        if let bodyFat = HKObjectType.quantityType(forIdentifier: .bodyFatPercentage) {
            types.insert(bodyFat)
        }
        return types
    }

    private func requestAuthorization(result: @escaping FlutterResult) {
        guard HKHealthStore.isHealthDataAvailable() else {
            result(false)
            return
        }
        // Apple's contract: the system surfaces the sheet only for types the
        // user has not yet seen prompts for. If everything is already
        // authorized (or denied) this is a no-op and `success` is true.
        healthStore.requestAuthorization(toShare: nil, read: profileReadTypes) { success, _ in
            DispatchQueue.main.async { result(success) }
        }
    }

    // MARK: - Read

    private func readProfile(result: @escaping FlutterResult) {
        guard HKHealthStore.isHealthDataAvailable() else {
            result([:])
            return
        }

        var payload: [String: Any] = [:]

        // Characteristics — synchronous reads. Each throws if the user denied
        // (or never granted) read access; we swallow per-field so a single
        // missing permission doesn't blank out the whole snapshot.
        if let dobComponents = try? healthStore.dateOfBirthComponents(),
           let dobDate = Calendar(identifier: .gregorian).date(from: dobComponents) {
            // ISO-8601 (date-only is fine; Dart parses with DateTime.tryParse).
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            payload["dateOfBirth"] = formatter.string(from: dobDate)
        }

        if let sexObject = try? healthStore.biologicalSex() {
            switch sexObject.biologicalSex {
            case .female: payload["biologicalSex"] = "female"
            case .male: payload["biologicalSex"] = "male"
            case .other: payload["biologicalSex"] = "other"
            case .notSet: break
            @unknown default: break
            }
        }

        if let bloodObject = try? healthStore.bloodType() {
            if let str = HealthKitProfileHandler.bloodTypeString(bloodObject.bloodType) {
                payload["bloodType"] = str
            }
        }

        // Latest sample reads — async. Run all three in parallel and reply
        // when the last one finishes.
        let group = DispatchGroup()

        if let heightType = HKObjectType.quantityType(forIdentifier: .height) {
            group.enter()
            fetchLatestQuantity(type: heightType, unit: HKUnit.meterUnit(with: .centi)) { value in
                if let v = value { payload["heightCm"] = v }
                group.leave()
            }
        }

        if let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass) {
            group.enter()
            fetchLatestQuantity(type: weightType, unit: .gramUnit(with: .kilo)) { value in
                if let v = value { payload["weightKg"] = v }
                group.leave()
            }
        }

        if let bodyFatType = HKObjectType.quantityType(forIdentifier: .bodyFatPercentage) {
            group.enter()
            fetchLatestQuantity(type: bodyFatType, unit: HKUnit.percent()) { value in
                // HealthKit returns body fat as a fraction (0.0–1.0); convert
                // to percent so the form's "Body Fat (%)" field renders 22.0
                // instead of 0.22.
                if let v = value { payload["bodyFatPercent"] = v * 100.0 }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            result(payload)
        }
    }

    private func fetchLatestQuantity(
        type: HKQuantityType,
        unit: HKUnit,
        completion: @escaping (Double?) -> Void
    ) {
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
        let query = HKSampleQuery(
            sampleType: type,
            predicate: nil,
            limit: 1,
            sortDescriptors: sort
        ) { _, samples, _ in
            guard let sample = samples?.first as? HKQuantitySample else {
                completion(nil)
                return
            }
            completion(sample.quantity.doubleValue(for: unit))
        }
        healthStore.execute(query)
    }

    // MARK: - Helpers

    private static func bloodTypeString(_ type: HKBloodType) -> String? {
        switch type {
        case .aPositive: return "A+"
        case .aNegative: return "A-"
        case .bPositive: return "B+"
        case .bNegative: return "B-"
        case .abPositive: return "AB+"
        case .abNegative: return "AB-"
        case .oPositive: return "O+"
        case .oNegative: return "O-"
        case .notSet: return nil
        @unknown default: return nil
        }
    }
}
