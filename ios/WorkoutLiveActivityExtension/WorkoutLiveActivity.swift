import ActivityKit
import Foundation
import SwiftUI
import WidgetKit

// Estrutura alinhada ao plugin `live_activities` (ActivityAttributes + ContentState com refreshToken).
struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
    public typealias LiveDeliveryData = ContentState

    public struct ContentState: Codable, Hashable {
        var appGroupId: String
        /// Muda a cada update para o sistema voltar a renderizar a Live Activity (ler App Group).
        var refreshToken: Int64
    }

    public var id: UUID

    public init(id: UUID = UUID()) {
        self.id = id
    }
}

extension LiveActivitiesAppAttributes {
    func prefixedKey(_ key: String) -> String {
        "\(id.uuidString)_\(key)"
    }
}

/// Mesmo identificador que em Dart [kIosWorkoutLiveActivitiesAppGroup].
private let kAppGroupId = "group.com.personaltrainer.appPersonal.workoutlive"

/// Um único `UserDefaults(suiteName:)` por processo da extensão. Recriar o suite a cada
/// `body` / tick do `TimelineView` faz o sistema ligar-se ao `cfprefsd` em loop e surgem
/// avisos do tipo «CFPrefsPlistSource… detaching from cfprefsd» no consola do Xcode.
private enum AppGroupUserDefaults {
    private static var cached: UserDefaults?
    private static let lock = NSLock()

    static var shared: UserDefaults? {
        lock.lock()
        defer { lock.unlock() }
        if let c = cached { return c }
        let u = UserDefaults(suiteName: kAppGroupId)
        cached = u
        return u
    }
}

private func registerNextSetURL(dayWorkoutId: String) -> URL {
    var c = URLComponents()
    c.scheme = "apppersonal"
    c.host = "workout"
    c.path = "/register-set"
    if !dayWorkoutId.isEmpty {
        c.queryItems = [URLQueryItem(name: "wid", value: dayWorkoutId)]
    }
    return c.url ?? URL(string: "apppersonal://workout/register-set")!
}

// Alinhado a `lib/core/theme/app_colors.dart` (Personal Gym).
private enum AppPalette {
    static let barBackground = Color(red: 0.039, green: 0.039, blue: 0.071) // 0xFF0A0A12
    static let backgroundDeep = Color(red: 0.035, green: 0, blue: 0.078) // 0xFF090014
    static let accentGreen = Color(red: 0.412, green: 0.941, blue: 0.682) // 0xFF69F0AE
    static let splashMint = Color(red: 0.510, green: 0.878, blue: 0.667) // 0xFF82E0AA
    static let accentPink = Color(red: 1, green: 0.255, blue: 0.506) // 0xFFFF4081
    static let headerPink = Color(red: 1, green: 0.176, blue: 0.471) // 0xFFFF2D78
    static let headerMint = Color(red: 0.439, green: 1, blue: 0.686) // 0xFF70FFAF
    static let cyanLight = Color(red: 0.506, green: 0.831, blue: 0.980) // 0xFF81D4FA

    static var headerGradient: LinearGradient {
        LinearGradient(
            colors: [headerPink, headerMint],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var timerGradient: LinearGradient {
        LinearGradient(
            colors: [accentGreen, splashMint, Color.white.opacity(0.95)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var borderGradient: LinearGradient {
        LinearGradient(
            colors: [
                headerPink.opacity(0.85),
                accentGreen.opacity(0.75),
                cyanLight.opacity(0.5),
                headerMint.opacity(0.45)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// Intervalo da regressiva do descanso (o sistema atualiza o `Text(timerInterval:)` na Live Activity).
private func workoutRestCountdownRange(
    ud: UserDefaults?,
    prefix: String,
    restEnd: Date
) -> ClosedRange<Date>? {
    let reMs = ud?.double(forKey: "\(prefix)_restEndMs") ?? 0
    guard reMs > 0 else { return nil }
    let rs = ud?.double(forKey: "\(prefix)_restStartMs") ?? 0
    let prescribed = ud?.integer(forKey: "\(prefix)_prescribedRest") ?? 0
    let fallbackSec = max(prescribed, 1)
    var start = rs > 0
        ? Date(timeIntervalSince1970: rs / 1000)
        : restEnd.addingTimeInterval(-Double(fallbackSec))
    if start >= restEnd {
        start = restEnd.addingTimeInterval(-1)
    }
    return start...restEnd
}

/// Cronómetro ascendente após o fim do intervalo, até `postEndMs` (ou janela longa se não vier da app).
private func workoutPostRestRange(
    ud: UserDefaults?,
    prefix: String,
    restEnd: Date
) -> ClosedRange<Date>? {
    let reMs = ud?.double(forKey: "\(prefix)_restEndMs") ?? 0
    guard reMs > 0 else { return nil }
    let ps = ud?.double(forKey: "\(prefix)_postStartMs") ?? 0
    let pe = ud?.double(forKey: "\(prefix)_postEndMs") ?? 0
    let postStart: Date
    if ps > 0 {
        let fromData = Date(timeIntervalSince1970: ps / 1000)
        postStart = max(fromData, restEnd)
    } else {
        postStart = restEnd
    }
    let postEnd: Date
    if pe > 0 {
        postEnd = Date(timeIntervalSince1970: pe / 1000)
    } else {
        postEnd = postStart.addingTimeInterval(6 * 3600)
    }
    if postEnd <= postStart {
        return postStart...postStart.addingTimeInterval(60)
    }
    return postStart...postEnd
}

@available(iOSApplicationExtension 16.1, *)
struct WorkoutLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            LockScreenWorkoutView(activityId: context.attributes.id)
                .activityBackgroundTint(AppPalette.barBackground.opacity(0.94))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    LockScreenWorkoutView(activityId: context.attributes.id, compact: false)
                }
            } compactLeading: {
                Image(systemName: "figure.run")
                    .foregroundStyle(AppPalette.accentGreen)
                    .symbolRenderingMode(.hierarchical)
            } compactTrailing: {
                Image(systemName: "timer")
                    .foregroundStyle(AppPalette.cyanLight)
                    .symbolRenderingMode(.hierarchical)
            } minimal: {
                Image(systemName: "figure.run")
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppPalette.headerPink, AppPalette.accentGreen],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        }
    }
}

@available(iOSApplicationExtension 16.1, *)
private struct LockScreenWorkoutView: View {
    let activityId: UUID
    var compact: Bool = true

    var body: some View {
        let ud = AppGroupUserDefaults.shared
        let prefix = activityId.uuidString
        let wid = ud?.string(forKey: "\(prefix)_dayWorkoutId") ?? ""
        let dest = registerNextSetURL(dayWorkoutId: wid)
        // Live Activity: dígitos com `Text(timerInterval:)` — o sistema atualiza no ecrã bloqueado (TimelineView não basta).
        let timerSize: CGFloat = compact ? 30 : 52
        let frozenSize: CGFloat = compact ? 26 : 42
        let vPad: CGFloat = compact ? 10 : 18
        let hPad: CGFloat = compact ? 12 : 18

        VStack(spacing: compact ? 4 : 10) {
            if compact {
                appNameHeaderCompact()
            } else {
                topBrandRow(compact: false)
            }

            tickingPhaseAndTimerColumn(timerSize: timerSize, frozenSize: frozenSize)
                .frame(maxWidth: .infinity)
                .padding(.vertical, compact ? 2 : 6)

            registerCTA(destination: dest, compact: compact)
        }
        .padding(.top, vPad)
        .padding(.bottom, vPad)
        .padding(.horizontal, hPad)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppPalette.backgroundDeep.opacity(0.98),
                                AppPalette.barBackground,
                                Color.black.opacity(0.92)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.35))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(AppPalette.borderGradient, lineWidth: compact ? 1.0 : 1.35)
        )
        .shadow(color: AppPalette.accentGreen.opacity(compact ? 0 : 0.1), radius: compact ? 0 : 16, y: compact ? 0 : 4)
        .widgetURL(dest)
    }

    /// Temporizadores com `Text(timerInterval:)` (atualização pelo sistema). TimelineView só para mudar chip regressiva → pós-intervalo.
    @ViewBuilder
    private func tickingPhaseAndTimerColumn(timerSize: CGFloat, frozenSize: CGFloat) -> some View {
        let ud = AppGroupUserDefaults.shared
        let p = activityId.uuidString
        let re = ud?.double(forKey: "\(p)_restEndMs") ?? 0

        if re > 0 {
            let restEnd = Date(timeIntervalSince1970: re / 1000)
            if let countRange = workoutRestCountdownRange(ud: ud, prefix: p, restEnd: restEnd),
               let postRange = workoutPostRestRange(ud: ud, prefix: p, restEnd: restEnd) {
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    let now = timeline.date
                    VStack(spacing: compact ? 3 : 8) {
                        if now < restEnd {
                            phaseChip(text: "INTERVALO", tint: AppPalette.cyanLight)
                            styledTimerIntervalText(interval: countRange, countsDown: true, size: timerSize)
                            captionLabel("Contagem regressiva")
                        } else if now < postRange.upperBound {
                            phaseChip(
                                text: compact ? "PÓS-INTERVALO" : "APÓS O INTERVALO",
                                tint: AppPalette.accentPink
                            )
                            styledTimerIntervalText(interval: postRange, countsDown: false, size: timerSize)
                            captionLabel("Pronto para a próxima série")
                        } else {
                            workoutNonRestTimerColumn(ud: ud, prefix: p, timerSize: timerSize, frozenSize: frozenSize)
                        }
                    }
                }
            } else {
                workoutNonRestTimerColumn(ud: ud, prefix: p, timerSize: timerSize, frozenSize: frozenSize)
            }
        } else {
            workoutNonRestTimerColumn(ud: ud, prefix: p, timerSize: timerSize, frozenSize: frozenSize)
        }
    }

    @ViewBuilder
    private func workoutNonRestTimerColumn(
        ud: UserDefaults?,
        prefix: String,
        timerSize: CGFloat,
        frozenSize: CGFloat
    ) -> some View {
        let phase = ud?.string(forKey: "\(prefix)_phase") ?? "idle"
        let frozen = ud?.string(forKey: "\(prefix)_workoutFrozenLabel") ?? ""
        let running = ud?.bool(forKey: "\(prefix)_workoutRunning") ?? false
        let vStart = ud?.double(forKey: "\(prefix)_workoutVirtualStartMs") ?? 0

        if running, vStart > 0 {
            let start = Date(timeIntervalSince1970: vStart / 1000)
            let end = start.addingTimeInterval(48 * 3600)
            VStack(spacing: compact ? 3 : 8) {
                phaseChip(text: "A DECORRER", tint: AppPalette.accentGreen)
                styledTimerIntervalText(interval: start...end, countsDown: false, size: timerSize)
                captionLabel("Tempo do treino")
            }
        } else if phase == "workout" {
            VStack(spacing: compact ? 3 : 8) {
                phaseChip(text: "PAUSADO", tint: AppPalette.headerMint.opacity(0.85))
                styledTimerDigits(frozen.isEmpty ? "—" : frozen, size: frozenSize)
                captionLabel("Treino em pausa")
            }
        } else {
            VStack(spacing: compact ? 3 : 8) {
                if !compact {
                    phaseChip(text: "PERSONAL GYM", tint: AppPalette.headerPink)
                }
                styledTimerDigits(frozen.isEmpty ? "—" : frozen, size: frozenSize)
                captionLabel("Treino ao vivo")
            }
        }
    }

    /// Sem gradiente nem sombra no `Text(timerInterval:)`: com `foregroundStyle(LinearGradient…)` o tempo costuma ficar
    /// congelado na Live Activity (o sistema deixa de tratar o texto como relógio animável).
    private func styledTimerIntervalText(interval: ClosedRange<Date>, countsDown: Bool, size: CGFloat) -> some View {
        Text(timerInterval: interval, countsDown: countsDown)
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .multilineTextAlignment(.center)
            .foregroundStyle(AppPalette.accentGreen)
            .padding(.vertical, compact ? 1 : 6)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private func captionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: compact ? 10 : 13, weight: .semibold))
            .foregroundStyle(.white.opacity(0.72))
            .multilineTextAlignment(.center)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
    }

    private func styledTimerDigits(_ text: String, size: CGFloat) -> some View {
        Text(text)
            .font(.system(size: size, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .multilineTextAlignment(.center)
            .foregroundStyle(AppPalette.timerGradient)
            .shadow(color: AppPalette.accentGreen.opacity(compact ? 0.2 : 0.5), radius: compact ? 2 : 14, y: 0)
            .shadow(color: AppPalette.headerPink.opacity(compact ? 0.12 : 0.28), radius: compact ? 1 : 10, y: compact ? 0 : 2)
            .padding(.vertical, compact ? 1 : 6)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    /// Nome da app sempre visível e centrado no lock screen (área baixa).
    private func appNameHeaderCompact() -> some View {
        Text("Personal Gym")
            .font(.system(size: 12, weight: .heavy))
            .tracking(0.4)
            .foregroundStyle(AppPalette.headerGradient)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.bottom, 1)
    }

    private func topBrandRow(compact: Bool) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: compact ? 12 : 14, weight: .bold))
                .foregroundStyle(AppPalette.headerGradient)
                .frame(height: compact ? 18 : 20, alignment: .center)
            Text("Personal Gym")
                .font(.system(size: compact ? 12 : 14, weight: .heavy))
                .foregroundStyle(AppPalette.headerGradient)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.vertical, compact ? 3 : 2)
            Spacer(minLength: 0)
            Capsule()
                .fill(AppPalette.accentGreen.opacity(0.2))
                .frame(width: 7, height: 7)
                .overlay(
                    Capsule()
                        .strokeBorder(AppPalette.accentGreen.opacity(0.9), lineWidth: 1)
                )
                .padding(.trailing, 1)
        }
        .padding(.top, compact ? 2 : 0)
        .padding(.bottom, compact ? 2 : 0)
    }

    private func phaseChip(text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: compact ? 8 : 10, weight: .heavy))
            .tracking(compact ? 0.6 : 1.1)
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, compact ? 8 : 14)
            .padding(.vertical, compact ? 3 : 6)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [tint.opacity(0.95), tint.opacity(0.35)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
            )
    }

    @ViewBuilder
    private func registerCTA(destination: URL, compact: Bool) -> some View {
        let label = HStack(alignment: .center, spacing: compact ? 6 : 10) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: compact ? 14 : 18, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(AppPalette.headerMint)
            Text(compact ? "Registar série" : "Registar próxima série")
                .font(.system(size: compact ? 11 : 14, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 2)
            Image(systemName: "chevron.right")
                .font(.system(size: compact ? 10 : 11, weight: .bold))
                .foregroundStyle(.white.opacity(0.75))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, compact ? 10 : 16)
        .padding(.vertical, compact ? 7 : 14)
        .background(
            RoundedRectangle(cornerRadius: compact ? 12 : 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            AppPalette.barBackground.opacity(0.95),
                            AppPalette.backgroundDeep.opacity(0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 12 : 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            AppPalette.headerPink.opacity(0.95),
                            AppPalette.accentGreen.opacity(0.85),
                            AppPalette.headerMint.opacity(0.7)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: compact ? 1.0 : 1.25
                )
        )
        .shadow(color: AppPalette.headerPink.opacity(compact ? 0 : 0.22), radius: compact ? 0 : 10, y: compact ? 0 : 4)

        if #available(iOSApplicationExtension 17.0, *) {
            Link(destination: destination) {
                label
            }
            .buttonStyle(.plain)
        } else {
            label
                .overlay(alignment: .bottomTrailing) {
                    Text("Abre o Personal Gym")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.65))
                        .padding(.trailing, 4)
                        .padding(.bottom, 2)
                }
        }
    }
}

@main
struct WorkoutLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        WorkoutLiveActivityWidget()
    }
}
