import Foundation

public struct TomikBreakActivities {
    private static let activitiesVi: [String] = [
        // Low-dopamine reset
        "📵 Low-dopamine reset: Tạm gác điện thoại, không lướt Shorts/TikTok để thụ thể não được nghỉ ngơi nhé!",
        "🧠 Hãy để não 'đói' dopamine một chút: Ngồi yên tĩnh, nhắm mắt và thả lỏng tâm trí.",
        "🌿 Nhìn ngắm cây xanh ngoài cửa sổ hoặc chậu cây nhỏ trên bàn để phục hồi năng lượng.",
        "🛋️ Rời khỏi bàn làm việc, chuyển sang ghế sofa hoặc ban công để đổi không gian mới.",
        "🎧 Tháo tai nghe ra, lắng nghe âm thanh tự nhiên xung quanh để làm dịu thính giác.",
        "🫧 Tự thưởng cho bản thân 5 phút tĩnh lặng tuyệt đối, không hấp thụ bất kỳ tin tức nào.",

        // Giãn cơ & vận động thể chất
        "🤸 Đứng dậy vươn vai thật cao, hít sâu kéo giãn cơ liên sườn và cột sống!",
        "💆 Nhún vai lên sát tai, giữ 3 giây rồi thả lỏng hoàn toàn (lặp lại 3 lần cho đỡ mỏi gáy).",
        "🔄 Xoay nhẹ nhàng khớp cổ sang trái, phải, cúi và ngửa để giải tỏa áp lực đốt sống cổ.",
        "🚶 Đứng dậy đi bộ nhẹ nhàng quanh phòng 30 bước giúp kích thích máu lưu thông lên não.",
        "🦵 Nhón gót chân lên xuống 15 lần để bơm máu từ chi dưới về tim tốt hơn.",
        "🤸 Đứng dậy nhảy nhẹ 5 cái và lắc lắc cổ tay cho đỡ mỏi cơ nào!",

        // Mắt & làm mát thần kinh
        "👀 Quy tắc 20-20-20: Nhìn ra xa ngoài cửa sổ ít nhất 6 mét trong vòng 20 giây để thư giãn mắt.",
        "🤲 Áp hai lòng bàn tay xoa ấm vào nhau rồi úp nhẹ lên mắt 15 giây (Palming).",
        "💧 Đi rửa mặt bằng nước mát hoặc uống một cốc nước ấm nạp lại độ ẩm cho cơ thể.",
        "🍎 Ăn một chút hoa quả hoặc hạt ngũ cốc nhẹ nhàng để tiếp thêm năng lượng lành mạnh.",

        // Hít thở & oxy cho não
        "🫁 Kỹ thuật thở 4-7-8: Hít vào 4 giây, giữ hơi 7 giây, thở chậm qua miệng 8 giây.",
        "🧘 Hít thở sâu 3 nhịp thật chậm rãi bằng cơ bụng cùng Tomik nào!",
        "✨ Thả lỏng cơ quai hàm – nơi chúng ta thường vô thức nghiến chặt khi đang tập trung cao độ.",
        "🍵 Nhâm nhi một ngụm trà thảo mộc ấm hoặc nước lọc thật chậm rãi."
    ]

    private static let activitiesEn: [String] = [
        // Low-dopamine reset
        "📵 Low-dopamine reset: Put your phone down, avoid Shorts/TikTok to let your dopamine receptors recover!",
        "🧠 Starve your brain of cheap dopamine: Sit quietly, close your eyes, and let your mind settle.",
        "🌿 Look at green plants or trees outside the window to recharge mental energy.",
        "🛋️ Step away from your desk, walk over to the couch or balcony for a quick change of scenery.",
        "🎧 Take off your headphones and enjoy natural ambient sounds to soothe your hearing.",
        "🫧 Reward yourself with 5 minutes of total silence—no news or feeds allowed.",

        // Stretching & physical movement
        "🤸 Stand up, reach high above your head, and take a deep stretch for your spine!",
        "💆 Shrug your shoulders up toward your ears, hold for 3 seconds, then release (repeat 3 times).",
        "🔄 Gently roll your neck in slow circles to relieve cervical tension.",
        "🚶 Walk around your room for 30 steps to boost blood circulation back to the brain.",
        "🦵 Do 15 gentle calf raises to pump blood from your legs back to your heart.",
        "🤸 Do 5 gentle hops and shake your wrists to release muscle stiffness!",

        // Eye care & refresh
        "👀 20-20-20 Rule: Look at something 20 feet away for 20 seconds to ease eye strain.",
        "🤲 Rub your palms together until warm, then cup them gently over your closed eyes (Palming).",
        "💧 Wash your face with cool water or grab a fresh glass of water.",
        "🍎 Grab a light piece of fruit or a handful of nuts for healthy sustained energy.",

        // Breath & oxygenation
        "🫁 4-7-8 Breathing: Inhale for 4s, hold for 7s, exhale slowly through your mouth for 8s.",
        "🧘 Take 3 slow, deep belly breaths with Tomik!",
        "✨ Unclench your jaw—we often tense facial muscles unknowingly when focusing deeply.",
        "🍵 Sip some warm herbal tea or water mindfully and slowly."
    ]

    public static func randomActivity() -> String {
        let currentLang = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
        let isVietnamese = currentLang == "vi"
        let pool = isVietnamese ? activitiesVi : activitiesEn
        return pool.randomElement() ?? (isVietnamese ? activitiesVi[0] : activitiesEn[0])
    }
}
