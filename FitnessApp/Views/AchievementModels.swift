//
//  AchievementModels.swift
//  FitnessApp
//
 
import SwiftUI
 
// MARK: - Achievement Category
 
enum AchievementCategory: String, CaseIterable, Codable {
    case streak      = "Streak"
    case workouts    = "Workouts"
    case variety     = "Variety"
    case calories    = "Calories"
    case nutrition   = "Nutrition"
    case water       = "Hydration"
    case weight      = "Weight"
    case volume      = "Volume"
    case social      = "Milestones"
 
    var icon: String {
        switch self {
        case .streak:    return "flame.fill"
        case .workouts:  return "dumbbell.fill"
        case .variety:   return "shuffle"
        case .calories:  return "bolt.fill"
        case .nutrition: return "fork.knife"
        case .water:     return "drop.fill"
        case .weight:    return "scalemass.fill"
        case .volume:    return "chart.bar.fill"
        case .social:    return "star.fill"
        }
    }
 
    var color: Color {
        switch self {
        case .streak:    return Color(hex: "FF6B35")
        case .workouts:  return Color(hex: "E84855")
        case .variety:   return Color(hex: "A855F7")
        case .calories:  return Color(hex: "3BB273")
        case .nutrition: return Color(hex: "F59E0B")
        case .water:     return Color(hex: "2196F3")
        case .weight:    return Color(hex: "9C6FE4")
        case .volume:    return Color(hex: "06B6D4")
        case .social:    return Color(hex: "FFB800")
        }
    }
}
 
// MARK: - Achievement Tier
 
enum AchievementTier: Int, Codable {
    case bronze = 1
    case silver = 2
    case gold   = 3
 
    var color: Color {
        switch self {
        case .bronze: return Color(hex: "CD7F32")
        case .silver: return Color(hex: "A8A9AD")
        case .gold:   return Color(hex: "FFD700")
        }
    }
    var label: String {
        switch self {
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold:   return "Gold"
        }
    }
    var ringColor: Color {
        switch self {
        case .bronze: return Color(hex: "CD7F32")
        case .silver: return Color(hex: "C0C0C8")
        case .gold:   return Color(hex: "FFD700")
        }
    }
}
 
// MARK: - Achievement Definition
 
struct AchievementDefinition: Identifiable {
    let id: String
    let category: AchievementCategory
    let title: String
    let description: String
    let funFact: String
    let tier: AchievementTier
    let badgeArt: AnyView
 
    init(id: String, category: AchievementCategory, title: String,
         description: String, funFact: String, tier: AchievementTier,
         @ViewBuilder art: () -> some View) {
        self.id = id; self.category = category; self.title = title
        self.description = description; self.funFact = funFact; self.tier = tier
        self.badgeArt = AnyView(art())
    }
}
 
// MARK: - All Achievement Definitions
 
extension AchievementDefinition {
    static let all: [AchievementDefinition] = [
 
        // ────────────────────────────────
        // MARK: STREAK
        // ────────────────────────────────
 
        .init(id: "streak_3", category: .streak,
              title: "Spark", description: "3 days in a row",
              funFact: "Three days is when habits actually start forming!", tier: .bronze) {
            ZStack {
                Ellipse().fill(Color(hex: "FF6B35").opacity(0.2)).frame(width: 26, height: 8).offset(y: 13)
                Path { p in
                    p.move(to: .init(x: 20, y: 30)); p.addQuadCurve(to: .init(x: 20, y: 5), control: .init(x: 10, y: 16))
                    p.addQuadCurve(to: .init(x: 20, y: 30), control: .init(x: 30, y: 16))
                }.fill(Color(hex: "FF6B35"))
                Path { p in
                    p.move(to: .init(x: 20, y: 27)); p.addQuadCurve(to: .init(x: 20, y: 11), control: .init(x: 13, y: 18))
                    p.addQuadCurve(to: .init(x: 20, y: 27), control: .init(x: 27, y: 18))
                }.fill(Color(hex: "FFB800"))
                Path { p in
                    p.move(to: .init(x: 20, y: 24)); p.addQuadCurve(to: .init(x: 20, y: 15), control: .init(x: 16, y: 19))
                    p.addQuadCurve(to: .init(x: 20, y: 24), control: .init(x: 24, y: 19))
                }.fill(Color.white.opacity(0.85))
            }.frame(width: 40, height: 40)
        },
 
        .init(id: "streak_7", category: .streak,
              title: "On Fire", description: "7 days in a row",
              funFact: "A full week — you're officially a creature of habit!", tier: .silver) {
            ZStack {
                ForEach(0..<3) { i in
                    Path { p in
                        let x = CGFloat(10 + i * 10)
                        p.move(to: .init(x: x, y: 34))
                        p.addQuadCurve(to: .init(x: x, y: 6 - CGFloat(i)*2), control: .init(x: x-7, y: 18))
                        p.addQuadCurve(to: .init(x: x, y: 34), control: .init(x: x+7, y: 18))
                    }.fill([Color(hex: "FF6B35"), Color(hex: "FFB800"), Color(hex: "FF3D00")][i])
                }
                Circle().fill(Color.white.opacity(0.9)).frame(width: 6, height: 6).offset(y: -7)
            }.frame(width: 40, height: 40)
        },
 
        .init(id: "streak_30", category: .streak,
              title: "Unstoppable", description: "30 days in a row",
              funFact: "30 days! Scientists say this is when neural pathways cement.", tier: .gold) {
            ZStack {
                ForEach(0..<8) { i in
                    Rectangle().fill(Color(hex: "FFD700")).frame(width: 2.5, height: 9).offset(y: -15)
                        .rotationEffect(.degrees(Double(i) * 45))
                }
                Circle().fill(Color(hex: "FFB800")).frame(width: 17, height: 17)
                Circle().fill(Color(hex: "FFD700")).frame(width: 11, height: 11)
                Path { p in
                    p.move(to: .init(x: 14, y: 9)); p.addLine(to: .init(x: 14, y: 5))
                    p.addLine(to: .init(x: 17, y: 7)); p.addLine(to: .init(x: 20, y: 4))
                    p.addLine(to: .init(x: 23, y: 7)); p.addLine(to: .init(x: 26, y: 5))
                    p.addLine(to: .init(x: 26, y: 9)); p.closeSubpath()
                }.fill(Color(hex: "FFD700")).offset(x: -6, y: -20)
            }.frame(width: 40, height: 40)
        },
 
        .init(id: "no_days_off", category: .streak,
              title: "No Days Off", description: "Log every day for a month",
              funFact: "Full month zero rest days — your dedication is elite.", tier: .gold) {
            ZStack {
                // calendar grid with all days filled
                ForEach(0..<5) { row in
                    ForEach(0..<7) { col in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color(hex: "FF6B35"))
                            .frame(width: 4, height: 4)
                            .offset(x: CGFloat(col)*6 - 18, y: CGFloat(row)*5 - 12)
                    }
                }
                // bold checkmark overlay
                Path { p in
                    p.move(to: .init(x: 11, y: 22)); p.addLine(to: .init(x: 17, y: 29))
                    p.addLine(to: .init(x: 29, y: 13))
                }.stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }.frame(width: 40, height: 40)
        },
 
        .init(id: "perfect_week", category: .streak,
              title: "Perfect Week", description: "All 7 days in a week",
              funFact: "A perfect 7/7 week. Less than 5% of users ever pull this off.", tier: .gold) {
            ZStack {
                ForEach(0..<7) { i in
                    Circle().fill(Color(hex: "FFD700")).frame(width: 6, height: 6)
                        .offset(y: -15).rotationEffect(.degrees(Double(i) * 360/7))
                }
                Path { p in
                    for i in 0..<5 {
                        let outer: CGFloat = 8, inner: CGFloat = 4
                        let angle = CGFloat(i) * 2 * .pi / 5 - .pi / 2
                        let x = 20 + outer * cos(angle), y = 20 + outer * sin(angle)
                        if i == 0 { p.move(to: .init(x: x, y: y)) } else { p.addLine(to: .init(x: x, y: y)) }
                        let ia = angle + .pi / 5
                        p.addLine(to: .init(x: 20 + inner * cos(ia), y: 20 + inner * sin(ia)))
                    }; p.closeSubpath()
                }.fill(Color(hex: "FFD700"))
            }.frame(width: 40, height: 40)
        },
 
        .init(id: "weekend_warrior", category: .streak,
              title: "Weekend Warrior", description: "Work out Sat & Sun",
              funFact: "While everyone rests, you grind. Respect.", tier: .silver) {
            ZStack {
                // shield shape
                Path { p in
                    p.move(to: .init(x: 20, y: 5)); p.addLine(to: .init(x: 33, y: 11))
                    p.addLine(to: .init(x: 33, y: 22))
                    p.addQuadCurve(to: .init(x: 20, y: 35), control: .init(x: 20, y: 32))
                    p.addQuadCurve(to: .init(x: 7, y: 22), control: .init(x: 20, y: 32))
                    p.addLine(to: .init(x: 7, y: 11)); p.closeSubpath()
                }.fill(Color(hex: "FF6B35"))
                // W letter
                Path { p in
                    p.move(to: .init(x: 13, y: 14)); p.addLine(to: .init(x: 16, y: 26))
                    p.addLine(to: .init(x: 20, y: 20)); p.addLine(to: .init(x: 24, y: 26))
                    p.addLine(to: .init(x: 27, y: 14))
                }.stroke(Color.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }.frame(width: 40, height: 40)
        },
 
        // ────────────────────────────────
        // MARK: WORKOUTS
        // ────────────────────────────────
 
        .init(id: "workouts_1", category: .workouts,
              title: "First Rep", description: "Complete your first workout",
              funFact: "Every champion started with workout #1.", tier: .bronze) {
            ZStack {
                RoundedRectangle(cornerRadius: 3).fill(Color(hex: "E84855")).frame(width: 28, height: 7)
                RoundedRectangle(cornerRadius: 4).fill(Color(hex: "E84855")).frame(width: 8, height: 14).offset(x: -12)
                RoundedRectangle(cornerRadius: 4).fill(Color(hex: "E84855")).frame(width: 8, height: 14).offset(x: 12)
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: "C0392B")).frame(width: 5, height: 18).offset(x: -12)
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: "C0392B")).frame(width: 5, height: 18).offset(x: 12)
            }.frame(width: 40, height: 40)
        },
 
        .init(id: "workouts_10", category: .workouts,
              title: "Getting Serious", description: "Complete 10 workouts",
              funFact: "10 workouts in — your body is already adapting.", tier: .bronze) {
            ZStack {
                RoundedRectangle(cornerRadius: 3).fill(Color(hex: "E84855")).frame(width: 30, height: 7)
                RoundedRectangle(cornerRadius: 4).fill(Color(hex: "E84855")).frame(width: 9, height: 16).offset(x: -13)
                RoundedRectangle(cornerRadius: 4).fill(Color(hex: "E84855")).frame(width: 9, height: 16).offset(x: 13)
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: "C0392B")).frame(width: 6, height: 20).offset(x: -13)
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: "C0392B")).frame(width: 6, height: 20).offset(x: 13)
                Ellipse().fill(Color(hex: "2196F3").opacity(0.85)).frame(width: 7, height: 9).offset(x: 7, y: -13)
                Path { p in
                    p.move(to: .init(x: 27, y: 8))
                    p.addQuadCurve(to: .init(x: 27, y: 13), control: .init(x: 23, y: 11))
                }.stroke(Color(hex: "64B5F6"), lineWidth: 1.5)
            }.frame(width: 40, height: 40)
        },
 
        .init(id: "workouts_50", category: .workouts,
              title: "Half Century", description: "Complete 50 workouts",
              funFact: "50 sessions — roughly 50 hours of becoming better.", tier: .silver) {
            ZStack {
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: "888")).frame(width: 34, height: 6)
                RoundedRectangle(cornerRadius: 5).fill(Color(hex: "E84855")).frame(width: 10, height: 22).offset(x: -15)
                RoundedRectangle(cornerRadius: 5).fill(Color(hex: "E84855")).frame(width: 10, height: 22).offset(x: 15)
                RoundedRectangle(cornerRadius: 3).fill(Color(hex: "C0392B")).frame(width: 6, height: 26).offset(x: -15)
                RoundedRectangle(cornerRadius: 3).fill(Color(hex: "C0392B")).frame(width: 6, height: 26).offset(x: 15)
                Text("50").font(.system(size: 9, weight: .black, design: .rounded)).foregroundColor(.white).offset(y: 1)
            }.frame(width: 40, height: 40)
        },
 
        .init(id: "workouts_100", category: .workouts,
              title: "Centurion", description: "Complete 100 workouts",
              funFact: "100 workouts. More gym time than most do in years.", tier: .gold) {
            ZStack {
                Path { p in
                    p.move(to: .init(x: 12, y: 8)); p.addLine(to: .init(x: 28, y: 8))
                    p.addLine(to: .init(x: 26, y: 22))
                    p.addQuadCurve(to: .init(x: 14, y: 22), control: .init(x: 20, y: 28))
                    p.closeSubpath()
                }.fill(Color(hex: "FFD700"))
                Rectangle().fill(Color(hex: "FFD700")).frame(width: 4, height: 7).offset(y: 11)
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: "FFB800")).frame(width: 14, height: 4).offset(y: 16)
                Path { p in
                    p.move(to: .init(x: 12, y: 11))
                    p.addQuadCurve(to: .init(x: 12, y: 19), control: .init(x: 6, y: 15))
                }.stroke(Color(hex: "FFD700"), lineWidth: 3)
                Path { p in
                    p.move(to: .init(x: 28, y: 11))
                    p.addQuadCurve(to: .init(x: 28, y: 19), control: .init(x: 34, y: 15))
                }.stroke(Color(hex: "FFD700"), lineWidth: 3)
                Text("100").font(.system(size: 7, weight: .black, design: .rounded)).foregroundColor(Color(hex: "854F0B")).offset(y: -2)
            }.frame(width: 40, height: 40)
        },
 
        .init(id: "double_session", category: .workouts,
              title: "Double Session", description: "Log 2 workouts in one day",
              funFact: "Two-a-days are an elite training technique. You're built different.", tier: .silver) {
            ZStack {
                // two dumbbells stacked
                Group {
                    RoundedRectangle(cornerRadius: 2).fill(Color(hex: "E84855")).frame(width: 22, height: 5)
                    RoundedRectangle(cornerRadius: 3).fill(Color(hex: "E84855")).frame(width: 6, height: 11).offset(x: -9)
                    RoundedRectangle(cornerRadius: 3).fill(Color(hex: "E84855")).frame(width: 6, height: 11).offset(x: 9)
                    RoundedRectangle(cornerRadius: 2).fill(Color(hex: "C0392B")).frame(width: 4, height: 14).offset(x: -9)
                    RoundedRectangle(cornerRadius: 2).fill(Color(hex: "C0392B")).frame(width: 4, height: 14).offset(x: 9)
                }.offset(y: -8)
                Group {
                    RoundedRectangle(cornerRadius: 2).fill(Color(hex: "E84855").opacity(0.6)).frame(width: 22, height: 5)
                    RoundedRectangle(cornerRadius: 3).fill(Color(hex: "E84855").opacity(0.6)).frame(width: 6, height: 11).offset(x: -9)
                    RoundedRectangle(cornerRadius: 3).fill(Color(hex: "E84855").opacity(0.6)).frame(width: 6, height: 11).offset(x: 9)
                }.offset(y: 9)
                Text("×2").font(.system(size: 8, weight: .black, design: .rounded)).foregroundColor(.white).offset(x: 12, y: 9)
            }.frame(width: 40, height: 40)
        },
 
        .init(id: "hour_club", category: .workouts,
              title: "Hour Club", description: "Log a 60+ minute workout",
              funFact: "60 minutes straight. That's serious commitment.", tier: .silver) {
            ZStack {
                // clock face
                Circle().stroke(Color(hex: "E84855"), lineWidth: 2.5).frame(width: 30, height: 30)
                // hour hand
                Rectangle().fill(Color(hex: "E84855")).frame(width: 2, height: 10)
                    .offset(y: -5).rotationEffect(.degrees(0))
                // minute hand (at 60 = 12)
                Rectangle().fill(Color(hex: "FFB800")).frame(width: 1.5, height: 12)
                    .offset(y: -6).rotationEffect(.degrees(0))
                Circle().fill(Color(hex: "E84855")).frame(width: 4, height: 4)
                // "60" label at bottom
                Text("60").font(.system(size: 7, weight: .black, design: .rounded)).foregroundColor(Color(hex: "E84855")).offset(y: 14)
            }.frame(width: 40, height: 40)
        },
 
        .init(id: "grind_50_days", category: .workouts,
              title: "The Grind", description: "50 total workout days",
              funFact: "50 days on the calendar marked. Most people never get here.", tier: .silver) {
            ZStack {
                // gear shape
                ForEach(0..<8) { i in
                    RoundedRectangle(cornerRadius: 2).fill(Color(hex: "E84855"))
                        .frame(width: 6, height: 14).offset(y: -14)
                        .rotationEffect(.degrees(Double(i) * 45))
                }
                Circle().fill(Color(hex: "C0392B")).frame(width: 18, height: 18)
                Text("50").font(.system(size: 8, weight: .black, design: .rounded)).foregroundColor(.white)
            }.frame(width: 40, height: 40)
        },
 
        // ────────────────────────────────
        // MARK: VARIETY
        // ────────────────────────────────
 
        .init(id: "jack_of_all_trades", category: .variety,
              title: "Jack of All Trades", description: "Try all 7 categories in a week",
              funFact: "All 7 categories — you literally do it all.", tier: .gold) {
            ZStack {
                // 7 colored dots in a circle
                let colors = ["FF6B35","E84855","A855F7","3BB273","2196F3","9C6FE4","FFB800"]
                ForEach(0..<7) { i in
                    Circle().fill(Color(hex: colors[i])).frame(width: 7, height: 7)
                        .offset(y: -14).rotationEffect(.degrees(Double(i) * 360/7))
                }
                Circle().fill(Color.white.opacity(0.15)).frame(width: 12, height: 12)
                Text("7").font(.system(size: 9, weight: .black, design: .rounded)).foregroundColor(.white)
            }.frame(width: 40, height: 40)
        },
 
        .init(id: "cardio_king", category: .variety,
              title: "Cardio King", description: "Complete 20 cardio workouts",
              funFact: "20 cardio sessions — your heart is a machine.", tier: .silver) {
            ZStack {
                // runner silhouette
                Circle().fill(Color(hex: "3BB273")).frame(width: 8, height: 8).offset(x: 4, y: -14)
                Path { p in
                    p.move(to: .init(x: 24, y: 10)); p.addLine(to: .init(x: 22, y: 20))
                    p.addLine(to: .init(x: 15, y: 26)); p.move(to: .init(x: 22, y: 20))
                    p.addLine(to: .init(x: 26, y: 28)); p.move(to: .init(x: 20, y: 15))
                    p.addLine(to: .init(x: 14, y: 18)); p.move(to: .init(x: 20, y: 15))
                    p.addLine(to: .init(x: 24, y: 12))
                }.stroke(Color(hex: "3BB273"), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                // speed lines
                ForEach(0..<3) { i in
                    Rectangle().fill(Color(hex: "3BB273").opacity(0.5))
                        .frame(width: CGFloat(8 - i*2), height: 1.5)
                        .offset(x: CGFloat(-8 + i), y: CGFloat(16 + i*4))
                }
            }.frame(width: 40, height: 40)
        },
 
        .init(id: "core_commander", category: .variety,
              title: "Core Commander", description: "Complete 15 core workouts",
              funFact: "15 core sessions — your abs are basically armor now.", tier: .silver) {
            ZStack {
                // abs grid
                let cols: [CGFloat] = [-5, 5]
                ForEach(0..<3) { row in
                    ForEach(0..<2) { col in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(hex: "FF6B35"))
                            .frame(width: 9, height: 7)
                            .offset(x: cols[col], y: CGFloat(row) * 10 - 10)
                    }
                }
                // center line
                Rectangle().fill(Color(hex: "C0392B")).frame(width: 2, height: 28).offset(y: 1)
            }.frame(width: 40, height: 40)
        },
 
        .init(id: "strength_beast", category: .variety,
              title: "Strength Beast", description: "Complete 30 strength workouts",
              funFact: "30 strength sessions — compound gains are compounding.", tier: .gold) {
            ZStack {
                // gorilla-style fist / power icon
                RoundedRectangle(cornerRadius: 5).fill(Color(hex: "E84855")).frame(width: 26, height: 22).offset(y: 4)
                // knuckle lines
                ForEach(0..<4) { i in
                    Rectangle().fill(Color(hex: "C0392B")).frame(width: 3, height: 6)
                        .offset(x: CGFloat(i)*6 - 9, y: -7)
                }
                RoundedRectangle(cornerRadius: 3).fill(Color(hex: "C0392B")).frame(width: 8, height: 10).offset(x: -12, y: 2)
                // lightning on fist
                Path { p in
                    p.move(to: .init(x: 22, y: 2)); p.addLine(to: .init(x: 17, y: 12))
                    p.addLine(to: .init(x: 21, y: 12)); p.addLine(to: .init(x: 18, y: 22))
                    p.addLine(to: .init(x: 24, y: 10)); p.addLine(to: .init(x: 20, y: 10)); p.closeSubpath()
                }.fill(Color(hex: "FFD700"))
            }.frame(width: 40, height: 40)
        },
 
        .init(id: "new_move", category: .variety,
              title: "New Move", description: "Log an exercise you've never done",
              funFact: "Trying new exercises keeps your muscles guessing. Smart training.", tier: .bronze) {
            ZStack {
                // plus in a burst
                ForEach(0..<6) { i in
                    Rectangle().fill(Color(hex: "A855F7").opacity(0.4))
                        .frame(width: 2, height: 8).offset(y: -14)
                        .rotationEffect(.degrees(Double(i) * 60))
                }
                Circle().fill(Color(hex: "A855F7").opacity(0.2)).frame(width: 20, height: 20)
                Path { p in
                    p.move(to: .init(x: 20, y: 13)); p.addLine(to: .init(x: 20, y: 27))
                    p.move(to: .init(x: 13, y: 20)); p.addLine(to: .init(x: 27, y: 20))
                }.stroke(Color(hex: "A855F7"), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }.frame(width: 40, height: 40)
        },
 
        // ────────────────────────────────
        // MARK: CALORIES
        // ────────────────────────────────
 
        .init(id: "calories_1000", category: .calories,
              title: "Spark Plug", description: "Burn 1,000 total calories",
              funFact: "1,000 kcal — that's about 10 miles walked!", tier: .bronze) {
            ZStack {
                Path { p in
                    p.move(to: .init(x: 23, y: 4)); p.addLine(to: .init(x: 13, y: 21))
                    p.addLine(to: .init(x: 20, y: 21)); p.addLine(to: .init(x: 16, y: 36))
                    p.addLine(to: .init(x: 28, y: 17)); p.addLine(to: .init(x: 21, y: 17)); p.closeSubpath()
                }.fill(Color(hex: "3BB273"))
            }.frame(width: 40, height: 40)
        },
 
        .init(id: "calories_5000", category: .calories,
              title: "Inferno", description: "Burn 5,000 total calories",
              funFact: "5,000 kcal — equivalent to running a full marathon!", tier: .silver) {
            ZStack {
                Path { p in
                    p.move(to: .init(x: 18, y: 4)); p.addLine(to: .init(x: 10, y: 20))
                    p.addLine(to: .init(x: 16, y: 20)); p.addLine(to: .init(x: 12, y: 34))
                    p.addLine(to: .init(x: 22, y: 16)); p.addLine(to: .init(x: 16, y: 16)); p.closeSubpath()
                }.fill(Color(hex: "3BB273").opacity(0.6))
                Path { p in
                    p.move(to: .init(x: 26, y: 4)); p.addLine(to: .init(x: 18, y: 20))
                    p.addLine(to: .init(x: 24, y: 20)); p.addLine(to: .init(x: 20, y: 34))
                    p.addLine(to: .init(x: 30, y: 16)); p.addLine(to: .init(x: 24, y: 16)); p.closeSubpath()
                }.fill(Color(hex: "3BB273"))
            }.frame(width: 40, height: 40)
        },
 
        .init(id: "calories_10000", category: .calories,
              title: "Furnace", description: "Burn 10,000 total calories",
              funFact: "10,000 kcal — you've literally burned off 3 lbs of pure fat!", tier: .gold) {
            ZStack {
                Circle().stroke(Color(hex: "3BB273"), lineWidth: 2.5).frame(width: 32, height: 32)
                Path { p in
                    p.move(to: .init(x: 22, y: 8)); p.addLine(to: .init(x: 15, y: 21))
                    p.addLine(to: .init(x: 20, y: 21)); p.addLine(to: .init(x: 18, y: 32))
                    p.addLine(to: .init(x: 25, y: 19)); p.addLine(to: .init(x: 20, y: 19)); p.closeSubpath()
                }.fill(Color(hex: "3BB273"))
            }.frame(width: 40, height: 40)
        },
 
        .init(id: "marathon_miles", category: .calories,
              title: "Marathon Man", description: "Log 26+ miles of cardio",
              funFact: "26.2 miles logged. You've covered a full marathon distance!", tier: .gold) {
            ZStack {
                // road with distance marker
                Path { p in
                    p.move(to: .init(x: 8, y: 32)); p.addQuadCurve(to: .init(x: 32, y: 32), control: .init(x: 20, y: 20))
                }.stroke(Color(hex: "3BB273"), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                // finish flag
                Rectangle().fill(Color(hex: "3BB273")).frame(width: 2, height: 16).offset(x: 10, y: -5)
                Path { p in
                    p.move(to: .init(x: 31, y: 9)); p.addLine(to: .init(x: 39, y: 13))
                    p.addLine(to: .init(x: 31, y: 17)); p.closeSubpath()
                }.fill(Color(hex: "FFD700")).offset(x: -8, y: -7)
                // 26 text
                Text("26").font(.system(size: 9, weight: .black, design: .rounded)).foregroundColor(Color(hex: "3BB273")).offset(y: 10)
            }.frame(width: 40, height: 40)
        },
 
        .init(id: "early_bird", category: .calories,
              title: "Early Bird", description: "Log a workout before 7am",
              funFact: "Morning workouts boost metabolism for the entire day.", tier: .bronze) {
            ZStack {
                ForEach(0..<5) { i in
                    Rectangle().fill(Color(hex: "FFB800")).frame(width: 2.5, height: 7)
                        .offset(y: -15).rotationEffect(.degrees(Double(i)*36 - 72))
                }
                Circle().fill(Color(hex: "FFD700")).frame(width: 14, height: 14).offset(y: 4)
                Rectangle().fill(Color(hex: "FFB800")).frame(width: 36, height: 2).offset(y: 13)
            }.frame(width: 40, height: 40)
        },
 
        // ────────────────────────────────
        // MARK: NUTRITION
        // ────────────────────────────────
 
        .init(id: "clean_plate", category: .nutrition,
              title: "Clean Plate", description: "Hit calorie goal ±50 kcal, 3 days running",
              funFact: "Precision nutrition 3 days straight — that's dietitian-level accuracy.", tier: .silver) {
            ZStack {
                // plate
                Circle().stroke(Color(hex: "F59E0B"), lineWidth: 2.5).frame(width: 30, height: 30)
                Circle().stroke(Color(hex: "F59E0B"), lineWidth: 1).frame(width: 22, height: 22)
                // fork & knife
                Path { p in
                    p.move(to: .init(x: 16, y: 10)); p.addLine(to: .init(x: 16, y: 22))
                    p.move(to: .init(x: 14, y: 10)); p.addLine(to: .init(x: 14, y: 14))
                    p.addQuadCurve(to: .init(x: 16, y: 16), control: .init(x: 16, y: 12))
                    p.move(to: .init(x: 18, y: 10)); p.addLine(to: .init(x: 18, y: 14))
                    p.addQuadCurve(to: .init(x: 16, y: 16), control: .init(x: 16, y: 12))
                }.stroke(Color(hex: "F59E0B"), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                Path { p in
                    p.move(to: .init(x: 24, y: 10)); p.addLine(to: .init(x: 24, y: 22))
                    p.addQuadCurve(to: .init(x: 26, y: 16), control: .init(x: 27, y: 19))
                    p.addLine(to: .init(x: 26, y: 10))
                }.stroke(Color(hex: "F59E0B"), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                // check
                Path { p in
                    p.move(to: .init(x: 15, y: 26)); p.addLine(to: .init(x: 18, y: 29))
                    p.addLine(to: .init(x: 25, y: 22))
                }.stroke(Color(hex: "3BB273"), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }.frame(width: 40, height: 40)
        },
 
        .init(id: "macro_master", category: .nutrition,
              title: "Macro Master", description: "Hit all 3 macros in one day",
              funFact: "Protein, carbs AND fat all on target? That takes real discipline.", tier: .gold) {
            ZStack {
                // three pie slices
                Path { p in
                    p.move(to: .init(x: 20, y: 20))
                    p.addArc(center: .init(x: 20, y: 20), radius: 14,
                             startAngle: .degrees(-90), endAngle: .degrees(30), clockwise: false)
                    p.closeSubpath()
                }.fill(Color(hex: "2196F3"))
                Path { p in
                    p.move(to: .init(x: 20, y: 20))
                    p.addArc(center: .init(x: 20, y: 20), radius: 14,
                             startAngle: .degrees(30), endAngle: .degrees(150), clockwise: false)
                    p.closeSubpath()
                }.fill(Color(hex: "3BB273"))
                Path { p in
                    p.move(to: .init(x: 20, y: 20))
                    p.addArc(center: .init(x: 20, y: 20), radius: 14,
                             startAngle: .degrees(150), endAngle: .degrees(270), clockwise: false)
                    p.closeSubpath()
                }.fill(Color(hex: "E84855"))
                Circle().fill(Color(hex: "1a1a2e")).frame(width: 10, height: 10)
                // center check
                Path { p in
                    p.move(to: .init(x: 17, y: 20)); p.addLine(to: .init(x: 19, y: 22))
                    p.addLine(to: .init(x: 23, y: 18))
                }.stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }.frame(width: 40, height: 40)
        },
 
        .init(id: "under_budget", category: .nutrition,
              title: "Under Budget", description: "Stay under calorie goal 7 days",
              funFact: "7 days in a calorie deficit. Your body is thanking you.", tier: .silver) {
            ZStack {
                // piggy bank / wallet shape
                RoundedRectangle(cornerRadius: 8).fill(Color(hex: "F59E0B")).frame(width: 28, height: 22).offset(y: 3)
                // coin slot
                RoundedRectangle(cornerRadius: 1).fill(Color(hex: "D97706")).frame(width: 10, height: 3).offset(y: -8)
                // down arrow (under budget)
                Path { p in
                    p.move(to: .init(x: 20, y: 8)); p.addLine(to: .init(x: 20, y: 18))
                    p.move(to: .init(x: 16, y: 14)); p.addLine(to: .init(x: 20, y: 19))
                    p.addLine(to: .init(x: 24, y: 14))
                }.stroke(Color.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                // ear
                Circle().stroke(Color(hex: "F59E0B"), lineWidth: 3).frame(width: 10, height: 10).offset(x: 14, y: 2)
                    .mask(Rectangle().frame(width: 8, height: 10).offset(x: 16, y: 2))
            }.frame(width: 40, height: 40)
        },
 
        // ────────────────────────────────
        // MARK: WATER
        // ────────────────────────────────
 
        .init(id: "water_7", category: .water,
              title: "Stay Hydrated", description: "Hit water goal 7 days",
              funFact: "7 days of hydration — your skin, joints, and brain are thanking you!", tier: .bronze) {
            ZStack {
                Path { p in
                    p.move(to: .init(x: 20, y: 6))
                    p.addQuadCurve(to: .init(x: 8, y: 24), control: .init(x: 4, y: 18))
                    p.addQuadCurve(to: .init(x: 20, y: 34), control: .init(x: 8, y: 32))
                    p.addQuadCurve(to: .init(x: 32, y: 24), control: .init(x: 32, y: 32))
                    p.addQuadCurve(to: .init(x: 20, y: 6), control: .init(x: 36, y: 18))
                }.fill(Color(hex: "2196F3"))
                Path { p in
                    p.move(to: .init(x: 15, y: 15))
                    p.addQuadCurve(to: .init(x: 13, y: 22), control: .init(x: 11, y: 18))
                }.stroke(Color.white.opacity(0.6), lineWidth: 2.5)
            }.frame(width: 40, height: 40)
        },
 
        .init(id: "water_30", category: .water,
              title: "Flood Gates", description: "Hit water goal 30 days",
              funFact: "30 days hitting your water goal. You're basically part dolphin.", tier: .gold) {
            ZStack {
                Path { p in
                    p.move(to: .init(x: 20, y: 4))
                    p.addQuadCurve(to: .init(x: 6, y: 24), control: .init(x: 2, y: 16))
                    p.addQuadCurve(to: .init(x: 20, y: 36), control: .init(x: 6, y: 34))
                    p.addQuadCurve(to: .init(x: 34, y: 24), control: .init(x: 34, y: 34))
                    p.addQuadCurve(to: .init(x: 20, y: 4), control: .init(x: 38, y: 16))
                }.fill(Color(hex: "2196F3"))
                ForEach(0..<3) { i in
                    Path { p in
                        let y = CGFloat(22 + i * 4)
                        p.move(to: .init(x: 11, y: y))
                        p.addQuadCurve(to: .init(x: 20, y: y-3), control: .init(x: 15, y: y-5))
                        p.addQuadCurve(to: .init(x: 29, y: y), control: .init(x: 25, y: y-5))
                    }.stroke(Color.white.opacity(0.5), lineWidth: 1.5)
                }
                Path { p in
                    p.move(to: .init(x: 15, y: 10)); p.addLine(to: .init(x: 15, y: 7))
                    p.addLine(to: .init(x: 18, y: 9)); p.addLine(to: .init(x: 20, y: 6))
                    p.addLine(to: .init(x: 22, y: 9)); p.addLine(to: .init(x: 25, y: 7))
                    p.addLine(to: .init(x: 25, y: 10)); p.closeSubpath()
                }.fill(Color(hex: "FFD700"))
            }.frame(width: 40, height: 40)
        },
 
        // ────────────────────────────────
        // MARK: WEIGHT
        // ────────────────────────────────
 
        .init(id: "weight_first", category: .weight,
              title: "On The Scale", description: "Log your first weight",
              funFact: "The first step to reaching your goal is knowing where you start.", tier: .bronze) {
            ZStack {
                RoundedRectangle(cornerRadius: 6).fill(Color(hex: "9C6FE4")).frame(width: 32, height: 22).offset(y: 6)
                Rectangle().fill(Color(hex: "7B52CC")).frame(width: 4, height: 6).offset(y: -6)
                Ellipse().fill(Color(hex: "7B52CC")).frame(width: 14, height: 5).offset(y: -8)
                Path { p in
                    p.move(to: .init(x: 14, y: 22)); p.addLine(to: .init(x: 18, y: 26))
                    p.addLine(to: .init(x: 26, y: 18))
                }.stroke(Color.white, lineWidth: 2.5)
            }.frame(width: 40, height: 40)
        },
 
        .init(id: "consistent_logger", category: .weight,
              title: "Consistent Logger", description: "Log weight 7 days in a row",
              funFact: "Daily weigh-ins show 40% better progress tracking. Science!", tier: .bronze) {
            ZStack {
                // 7 tick marks
                ForEach(0..<7) { i in
                    Rectangle().fill(i < 7 ? Color(hex: "9C6FE4") : Color.gray.opacity(0.3))
                        .frame(width: 3, height: i % 3 == 0 ? 12 : 8)
                        .offset(x: CGFloat(i)*5 - 15, y: 0)
                }
                // scale base
                RoundedRectangle(cornerRadius: 3).fill(Color(hex: "7B52CC")).frame(width: 36, height: 6).offset(y: 12)
            }.frame(width: 40, height: 40)
        },
 
        .init(id: "month_tracker", category: .weight,
              title: "Month Tracker", description: "Log weight every week for a month",
              funFact: "4 weeks of data — your trend line is actually meaningful now.", tier: .silver) {
            ZStack {
                // sparkline graph
                Path { p in
                    p.move(to: .init(x: 6, y: 28))
                    p.addLine(to: .init(x: 14, y: 22))
                    p.addLine(to: .init(x: 22, y: 18))
                    p.addLine(to: .init(x: 30, y: 14))
                    p.addLine(to: .init(x: 34, y: 10))
                }.stroke(Color(hex: "9C6FE4"), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                // dots on line
                ForEach([CGPoint(x:6,y:28), CGPoint(x:14,y:22), CGPoint(x:22,y:18), CGPoint(x:30,y:14)], id: \.x) { pt in
                    Circle().fill(Color(hex: "9C6FE4")).frame(width: 6, height: 6).offset(x: pt.x-20, y: pt.y-20)
                }
                // calendar lines at bottom
                Rectangle().fill(Color(hex: "7B52CC").opacity(0.4)).frame(width: 32, height: 1).offset(y: 14)
            }.frame(width: 40, height: 40)
        },
 
        .init(id: "data_nerd", category: .weight,
              title: "Data Nerd", description: "Have 30+ weight entries",
              funFact: "30 data points — your trend is statistically significant. You're basically a scientist.", tier: .gold) {
            ZStack {
                // bar chart
                let heights: [CGFloat] = [16, 20, 14, 24, 18, 22, 26]
                let colors = ["9C6FE4","7B52CC","9C6FE4","A855F7","9C6FE4","7B52CC","FFD700"]
                ForEach(0..<7) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: colors[i]))
                        .frame(width: 4, height: heights[i])
                        .offset(x: CGFloat(i)*5 - 15, y: CGFloat(26 - heights[i]/2) - 14)
                }
                // glasses (nerd)
                Circle().stroke(Color.white, lineWidth: 1.5).frame(width: 8, height: 8).offset(x: -5, y: -13)
                Circle().stroke(Color.white, lineWidth: 1.5).frame(width: 8, height: 8).offset(x: 5, y: -13)
                Path { p in
                    p.move(to: .init(x: 17, y: 7)); p.addLine(to: .init(x: 23, y: 7))
                }.stroke(Color.white, lineWidth: 1.5)
                Rectangle().fill(Color.white).frame(width: 5, height: 1.5).offset(x: -12, y: -13)
                Rectangle().fill(Color.white).frame(width: 5, height: 1.5).offset(x: 12, y: -13)
            }.frame(width: 40, height: 40)
        },
 
        .init(id: "weight_goal", category: .weight,
              title: "Goal Crusher", description: "Reach your target weight",
              funFact: "You actually did it. Target reached. This one's rare.", tier: .gold) {
            ZStack {
                Circle().stroke(Color(hex: "9C6FE4").opacity(0.3), lineWidth: 3).frame(width: 36, height: 36)
                Circle().stroke(Color(hex: "9C6FE4").opacity(0.6), lineWidth: 3).frame(width: 24, height: 24)
                Circle().fill(Color(hex: "9C6FE4")).frame(width: 12, height: 12)
                ForEach(0..<6) { i in
                    Rectangle().fill(Color(hex: "FFD700")).frame(width: 2, height: 6).offset(y: -22)
                        .rotationEffect(.degrees(Double(i) * 60))
                }
            }.frame(width: 40, height: 40)
        },
 
        // ────────────────────────────────
        // MARK: VOLUME
        // ────────────────────────────────
 
        .init(id: "iron_ton", category: .volume,
              title: "Iron Ton", description: "Lift 10,000 lbs total",
              funFact: "10,000 lbs lifted. That's heavier than a fully loaded school bus.", tier: .gold) {
            ZStack {
                // anvil silhouette
                RoundedRectangle(cornerRadius: 3).fill(Color(hex: "06B6D4")).frame(width: 28, height: 14).offset(y: 2)
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: "0891B2")).frame(width: 18, height: 8).offset(y: 12)
                // 10K label
                Text("10K").font(.system(size: 8, weight: .black, design: .rounded)).foregroundColor(.white).offset(y: 2)
                // weight plates suggestion
                Rectangle().fill(Color(hex: "0891B2")).frame(width: 3, height: 20).offset(x: -16, y: 2)
                Rectangle().fill(Color(hex: "0891B2")).frame(width: 3, height: 20).offset(x: 16, y: 2)
            }.frame(width: 40, height: 40)
        },
 
        // ────────────────────────────────
        // MARK: MILESTONES
        // ────────────────────────────────
 
        .init(id: "early_bird_social", category: .social,
              title: "Night Owl", description: "Log a workout after 9pm",
              funFact: "Training at night? Your body temp peaks at 6pm — strength gains are real.", tier: .bronze) {
            ZStack {
                // crescent moon
                Circle().fill(Color(hex: "6366F1")).frame(width: 26, height: 26)
                Circle().fill(Color(hex: "0d1b2a")).frame(width: 20, height: 20).offset(x: 6, y: -4)
                // stars
                ForEach(0..<4) { i in
                    let positions = [CGPoint(x:8,y:-14), CGPoint(x:14,y:-10), CGPoint(x:2,y:-6), CGPoint(x:11,y:-4)]
                    Circle().fill(Color.white).frame(width: 2.5, height: 2.5)
                        .offset(x: positions[i].x - 4, y: positions[i].y)
                }
            }.frame(width: 40, height: 40)
        },
 
        .init(id: "lunch_break_hero", category: .social,
              title: "Lunch Break Hero", description: "Work out between 12–2pm",
              funFact: "Midday workouts improve afternoon focus by up to 20%.", tier: .bronze) {
            ZStack {
                // sandwich / lunch icon
                RoundedRectangle(cornerRadius: 4).fill(Color(hex: "F59E0B")).frame(width: 30, height: 8).offset(y: -8)
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: "3BB273")).frame(width: 26, height: 5).offset(y: -2)
                RoundedRectangle(cornerRadius: 2).fill(Color(hex: "E84855")).frame(width: 26, height: 4).offset(y: 3)
                RoundedRectangle(cornerRadius: 4).fill(Color(hex: "F59E0B")).frame(width: 30, height: 8).offset(y: 8)
                // lightning bolt on top
                Path { p in
                    p.move(to: .init(x: 22, y: -18)); p.addLine(to: .init(x: 18, y: -11))
                    p.addLine(to: .init(x: 21, y: -11)); p.addLine(to: .init(x: 18, y: -4))
                    p.addLine(to: .init(x: 23, y: -12)); p.addLine(to: .init(x: 20, y: -12))
                    p.closeSubpath()
                }.fill(Color(hex: "FFD700"))
            }.frame(width: 40, height: 40)
        },
 
        .init(id: "overachiever", category: .social,
              title: "Overachiever", description: "Beat weekly goal 3 weeks running",
              funFact: "3 weeks of going above and beyond. The definition of extra.", tier: .gold) {
            ZStack {
                // upward chart bars
                let bh: [CGFloat] = [10, 16, 22, 28]
                ForEach(0..<4) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(i == 3 ? Color(hex: "FFD700") : Color(hex: "FFB800").opacity(0.5 + Double(i)*0.15))
                        .frame(width: 6, height: bh[i])
                        .offset(x: CGFloat(i)*8 - 12, y: CGFloat(26) - bh[i]/2 - 12)
                }
                // star above last bar
                Path { p in
                    for s in 0..<5 {
                        let outer: CGFloat = 6, inner: CGFloat = 3
                        let angle = CGFloat(s) * 2 * .pi / 5 - .pi / 2
                        let x = 32 + outer * cos(angle), y = 4 + outer * sin(angle)
                        if s == 0 { p.move(to: .init(x: x, y: y)) } else { p.addLine(to: .init(x: x, y: y)) }
                        let ia = angle + .pi / 5
                        p.addLine(to: .init(x: 32 + inner*cos(ia), y: 4 + inner*sin(ia)))
                    }; p.closeSubpath()
                }.fill(Color(hex: "FFD700")).offset(x: -12, y: -4)
            }.frame(width: 40, height: 40)
        },
 
        .init(id: "ghost_mode", category: .social,
              title: "Ghost Mode", description: "Log a workout with 0 calories",
              funFact: "Pure mobility, breath work, or stretching — recovery is training too.", tier: .bronze) {
            ZStack {
                // ghost shape
                Path { p in
                    p.move(to: .init(x: 13, y: 32))
                    p.addLine(to: .init(x: 13, y: 16))
                    p.addArc(center: .init(x: 20, y: 16), radius: 7, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
                    p.addLine(to: .init(x: 27, y: 32))
                    p.addLine(to: .init(x: 24, y: 28)); p.addLine(to: .init(x: 21, y: 32))
                    p.addLine(to: .init(x: 20, y: 28)); p.addLine(to: .init(x: 19, y: 32))
                    p.addLine(to: .init(x: 16, y: 28)); p.closeSubpath()
                }.fill(Color(hex: "A855F7").opacity(0.7))
                // eyes
                Circle().fill(Color.white).frame(width: 5, height: 5).offset(x: -3, y: -2)
                Circle().fill(Color.white).frame(width: 5, height: 5).offset(x: 3, y: -2)
                Circle().fill(Color(hex: "0d1b2a")).frame(width: 2.5, height: 2.5).offset(x: -3, y: -2)
                Circle().fill(Color(hex: "0d1b2a")).frame(width: 2.5, height: 2.5).offset(x: 3, y: -2)
            }.frame(width: 40, height: 40)
        },
 
        .init(id: "creature_of_habit", category: .social,
              title: "Creature of Habit", description: "Log the same workout 5 times",
              funFact: "Repetition is the mother of mastery. Same move, 5 times over.", tier: .silver) {
            ZStack {
                // circular arrows (repeat icon)
                Circle().stroke(Color(hex: "FFB800"), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [4,2])).frame(width: 28, height: 28)
                // arrow head
                Path { p in
                    p.move(to: .init(x: 20, y: 6)); p.addLine(to: .init(x: 26, y: 11))
                    p.addLine(to: .init(x: 19, y: 12))
                }.fill(Color(hex: "FFB800"))
                // "×5" text
                Text("×5").font(.system(size: 10, weight: .black, design: .rounded)).foregroundColor(Color(hex: "FFB800"))
            }.frame(width: 40, height: 40)
        },
 
        .init(id: "comeback_kid", category: .social,
              title: "Comeback Kid", description: "Return after 7+ days off",
              funFact: "Getting back after a break is harder than never stopping. Respect.", tier: .silver) {
            ZStack {
                Circle().stroke(Color(hex: "FFB800"), lineWidth: 3).frame(width: 28, height: 28)
                    .trim(from: 0.1, to: 0.9).rotationEffect(.degrees(-90))
                Path { p in
                    p.move(to: .init(x: 24, y: 9)); p.addLine(to: .init(x: 29, y: 14))
                    p.addLine(to: .init(x: 22, y: 15))
                }.fill(Color(hex: "FFB800"))
                Path { p in
                    p.move(to: .init(x: 20, y: 23))
                    p.addQuadCurve(to: .init(x: 20, y: 17), control: .init(x: 13, y: 17))
                    p.addQuadCurve(to: .init(x: 20, y: 23), control: .init(x: 27, y: 17))
                }.fill(Color(hex: "E84855"))
            }.frame(width: 40, height: 40)
        },
    ]
 
    static func find(_ id: String) -> AchievementDefinition? { all.first { $0.id == id } }
}
 
// MARK: - Unlocked Achievement
 
struct UnlockedAchievement: Codable, Identifiable {
    let id: String
    let unlockedAt: Date
    enum CodingKeys: String, CodingKey { case id; case unlockedAt = "unlocked_at" }
}
 
// MARK: - Achievement Engine
 
struct AchievementEngine {
    static func evaluate(
        existing: Set<String>,
        workoutStreak: Int,
        totalWorkouts: Int,
        totalCaloriesBurned: Int,
        waterGoalDaysHit: Int,
        weightEntries: [WeightHistoryEntry],
        targetWeightLbs: Double?,
        hasEarlyBirdWorkout: Bool = false,
        hasNightOwlWorkout: Bool = false,
        hasLunchBreakWorkout: Bool = false,
        hadBreakBeforeReturn: Bool = false,
        hasZeroCalWorkout: Bool = false,
        hasSameWorkout5Times: Bool = false,
        hasDoubleSessionDay: Bool = false,
        longestWorkoutMinutes: Int = 0,
        totalMilesCardio: Double = 0,
        totalLiftedLbs: Double = 0,
        categoriesThisWeek: Set<String> = [],
        weekendWorkoutsThisWeek: Int = 0,
        caloriePrecisionDays: Int = 0,
        underBudgetDays: Int = 0,
        macroHitDays: Int = 0,
        weightLogDaysStreak: Int = 0,
        weightLogWeeks: Int = 0,
        totalWeightEntries: Int = 0,
        weeksAboveGoal: Int = 0,
        hasNewExercise: Bool = false,
        cardioWorkouts: Int = 0,
        coreWorkouts: Int = 0,
        strengthWorkouts: Int = 0,
        hasLogged30DaysAny: Bool = false
    ) -> [String] {
        var toUnlock: [String] = []
        func check(_ id: String, condition: Bool) {
            if condition && !existing.contains(id) { toUnlock.append(id) }
        }
 
        // Streaks
        check("streak_3",       condition: workoutStreak >= 3)
        check("streak_7",       condition: workoutStreak >= 7)
        check("streak_30",      condition: workoutStreak >= 30)
        check("no_days_off",    condition: hasLogged30DaysAny)
        check("perfect_week",   condition: workoutStreak >= 7)
        check("weekend_warrior",condition: weekendWorkoutsThisWeek >= 2)
 
        // Workouts
        check("workouts_1",     condition: totalWorkouts >= 1)
        check("workouts_10",    condition: totalWorkouts >= 10)
        check("workouts_50",    condition: totalWorkouts >= 50)
        check("workouts_100",   condition: totalWorkouts >= 100)
        check("double_session", condition: hasDoubleSessionDay)
        check("hour_club",      condition: longestWorkoutMinutes >= 60)
        check("grind_50_days",  condition: totalWorkouts >= 50)
 
        // Variety
        check("jack_of_all_trades", condition: categoriesThisWeek.count >= 7)
        check("cardio_king",    condition: cardioWorkouts >= 20)
        check("core_commander", condition: coreWorkouts >= 15)
        check("strength_beast", condition: strengthWorkouts >= 30)
        check("new_move",       condition: hasNewExercise)
 
        // Calories
        check("calories_1000",  condition: totalCaloriesBurned >= 1_000)
        check("calories_5000",  condition: totalCaloriesBurned >= 5_000)
        check("calories_10000", condition: totalCaloriesBurned >= 10_000)
        check("marathon_miles", condition: totalMilesCardio >= 26.2)
        check("early_bird",     condition: hasEarlyBirdWorkout)
 
        // Nutrition
        check("clean_plate",    condition: caloriePrecisionDays >= 3)
        check("macro_master",   condition: macroHitDays >= 1)
        check("under_budget",   condition: underBudgetDays >= 7)
 
        // Water
        check("water_7",        condition: waterGoalDaysHit >= 7)
        check("water_30",       condition: waterGoalDaysHit >= 30)
 
        // Weight
        check("weight_first",       condition: !weightEntries.isEmpty)
        check("consistent_logger",  condition: weightLogDaysStreak >= 7)
        check("month_tracker",      condition: weightLogWeeks >= 4)
        check("data_nerd",          condition: totalWeightEntries >= 30)
        if let last = weightEntries.last?.weight_lbs, let target = targetWeightLbs, weightEntries.count >= 2 {
            check("weight_goal", condition: last <= target)
        }
 
        // Volume
        check("iron_ton",       condition: totalLiftedLbs >= 10_000)
 
        // Milestones
        check("early_bird_social",   condition: hasNightOwlWorkout)
        check("lunch_break_hero",    condition: hasLunchBreakWorkout)
        check("overachiever",        condition: weeksAboveGoal >= 3)
        check("ghost_mode",          condition: hasZeroCalWorkout)
        check("creature_of_habit",   condition: hasSameWorkout5Times)
        check("comeback_kid",        condition: hadBreakBeforeReturn)
 
        return toUnlock
    }
}
