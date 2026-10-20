import Foundation

public struct TomikBreakActivities {
    private static let activitiesVi = [
        "💧 Uống một cốc nước lọc và vươn vai 3 lần!",
        "👀 Nhìn ra xa ngoài cửa sổ 20 giây để thư giãn mắt nhé!",
        "🤸 Đứng dậy nhảy nhẹ 5 cái cho đỡ mỏi lưng!",
        "🍎 Rửa mặt hoặc ăn một chút hoa quả tiếp sức nhé!",
        "🧘 Hít thở sâu 3 nhịp thật chậm rãi cùng Tomik!"
    ]

    private static let activitiesEn = [
        "💧 Drink a glass of water and stretch 3 times!",
        "👀 Look out the window 20 feet away for 20 seconds to relax your eyes!",
        "🤸 Stand up and do 5 gentle jumps to stretch your back!",
        "🍎 Wash your face or grab a light fruit snack!",
        "🧘 Take 3 deep, slow breaths with Tomik!"
    ]

    public static func randomActivity() -> String {
        let isVietnamese = Locale.current.language.languageCode?.identifier == "vi"
        let pool = isVietnamese ? activitiesVi : activitiesEn
        return pool.randomElement() ?? activitiesVi[0]
    }
}
