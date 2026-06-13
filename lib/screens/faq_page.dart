import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/lang.dart';

class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

  List<_FaqItem> _getFaqItems(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    
    if (isArabic) {
      return const [
        _FaqItem(
          question: '1. ما هي درجة الحرارة المثالية للنحل؟',
          answer: 'يزدهر النحل بين 32 درجة مئوية و35 درجة مئوية. هذا هو النطاق المثالي للملكة لوضع البيض ولتطور الحضنة بشكل صحي.',
        ),
        _FaqItem(
          question: '2. لماذا تعتبر الرطوبة العالية (أكثر من 75٪) خطيرة؟',
          answer: 'الرطوبة الزائدة تجعل من الصعب على النحل تجفيف الرحيق وتحويله إلى عسل. كما يمكن أن تسبب العفن داخل الخلية، مما يمرض الطائفة.',
        ),
        _FaqItem(
          question: '3. ماذا أفعل إذا تجاوزت درجة الحرارة 38 درجة مئوية؟',
          answer: 'هذه منطقة خطر! تأكد من وجود ظل للخلية وأن المدخل مفتوح تماماً. يمكنك وضع غطاء مظلل أو توفير مصدر مياه قريب لمساعدتهم على التبريد.',
        ),
        _FaqItem(
          question: '4. كيف يبقى النحل دافئاً في الشتاء؟',
          answer: 'يشكلون عنقوداً متراصاً ويهزون أجسامهم لتوليد الحرارة. إذا أظهر التطبيق درجات حرارة منخفضة جداً، فتأكد من عزل الخلية جيداً ولا تفتحها أبداً في البرد.',
        ),
        _FaqItem(
          question: '5. متى هو أفضل وقت لتغذية الطائفة؟',
          answer: 'قم بتغذيتهم بمحلول سكري إذا أظهر التطبيق فترة طويلة من الأمطار أو إذا كان الوقت مبكراً في الربيع ولم يتبق لديهم مخزون من العسل.',
        ),
        _FaqItem(
          question: '6. أرى النحل يقوم بـ "التهوية" عند المدخل، لماذا؟',
          answer: 'إنهم يعملون كأجهزة تكييف! يحركون أجنحتهم لإخراج الهواء الساخن. تحقق من تطبيقك؛ ستلاحظ على الأرجح ارتفاع درجة الحرارة.',
        ),
        _FaqItem(
          question: '7. كيف يقلل التطبيق من عمليات فحص الخلايا؟',
          answer: 'بدلاً من فتح الخلية كل يوم وإزعاج النحل، لا تفتحها إلا عندما يظهر التطبيق وجود خطأ ما (مثل الانخفاض المفاجئ في درجة الحرارة).',
        ),
        _FaqItem(
          question: '8. أين يجب أن أضع جهاز Smart Bee؟',
          answer: 'أفضل مكان هو فوق إطارات الحضنة، تحت الغطاء الداخلي. هذا يعطي القراءة الأكثر دقة لصحة قلب الطائفة.',
        ),
        _FaqItem(
          question: '9. ماذا لو لم يكن لدى منحلتي شبكة Wi-Fi؟',
          answer: 'يحتاج الجهاز إلى اتصال لإرسال البيانات الحية. يستخدم معظم المزارعين راوتر 4G/5G صغيراً يوضع في المنحل لتغطية جميع الخلايا.',
        ),
        _FaqItem(
          question: '10. هل الجهاز آمن من العكبر (البروبوليس)؟',
          answer: 'نعم، ولكن من الأفضل وضعه داخل علبة بلاستيكية صغيرة مهواة لمنع النحل من تغطية المستشعر بالشمع أو العكبر.',
        ),
        _FaqItem(
          question: '11. ماذا يحدث إذا انقطع الإنترنت؟',
          answer: 'سيستمر الجهاز في القياس. بمجرد عودة الاتصال، سيقوم بمزامنة أحدث البيانات مع هاتفك تلقائياً.',
        ),
        _FaqItem(
          question: '12. ما مدى دقة مستشعر DHT22؟',
          answer: 'إنه دقيق للغاية لتربية النحل، حيث يقيس درجة الحرارة ضمن 0.5 درجة مئوية والرطوبة ضمن 2-5٪.',
        ),
        _FaqItem(
          question: '13. هل يمكن للجهاز الصمود أمام المطر والحرارة؟',
          answer: 'بما أنه يوضع داخل الخلية، فهو محمي من المطر. وهو مصمم لتحمل درجات الحرارة الطبيعية العالية لخلية النحل.',
        ),
        _FaqItem(
          question: '14. لماذا أصبحت بطاقة خليتي "OFFLINE"؟',
          answer: 'هذا يعني عدم وصول بيانات لمدة 30 دقيقة. قد يكون ذلك بسبب ضعف إشارة Wi-Fi أو انقطاع الطاقة عن الجهاز.',
        ),
        _FaqItem(
          question: '15. ما هو "رمز وصول المسؤول"؟',
          answer: 'إنه رمز أمان (2026) يسمح للمالك بتغيير الإعدادات وإدارة الأذونات ورؤية جميع الخلايا.',
        ),
        _FaqItem(
          question: '16. كيف تعمل "تنبيهات الدفع" (Push Alerts)؟',
          answer: 'إذا وصلت الحرارة أو الرطوبة إلى مستوى حرج، سيرن هاتفك حتى لو كان في جيبك. تأكد من تفعيل الإشعارات والسماح بالعمل في الخلفية من نافذة الإعداد الأولية.',
        ),
        _FaqItem(
          question: '17. هل يمكنني رؤية تاريخ خليتي؟',
          answer: 'نعم! اضغط على أي بطاقة خلية لرؤية مخطط كامل لكيفية تغير درجة الحرارة والرطوبة طوال اليوم.',
        ),
        _FaqItem(
          question: '18. هل بياناتي خاصة؟',
          answer: 'نعم، فقط أنت والأشخاص الذين تمنحهم الإذن يمكنهم رؤية بيانات خليتك من خلال نظام Smart Bee.',
        ),
      ];
    } else {
      return const [
        _FaqItem(
          question: '1. What is the ideal temperature for my bees?',
          answer: 'Bees thrive between 32°C and 35°C. This is the perfect range for the queen to lay eggs and for the brood to develop healthy.',
        ),
        _FaqItem(
          question: '2. Why is high humidity (over 75%) dangerous?',
          answer: 'Too much moisture makes it hard for bees to dry nectar into honey. It can also cause mold inside the hive, which makes the colony sick.',
        ),
        _FaqItem(
          question: '3. What should I do if the temperature exceeds 38°C?',
          answer: 'This is a danger zone! Ensure the hive has shade and the entrance is clear. You can place a shaded cover or provide a nearby water source to help them cool down.',
        ),
        _FaqItem(
          question: '4. How do bees stay warm in the winter?',
          answer: 'They form a tight cluster and vibrate their bodies to generate heat. If the app shows very low temps, ensure the hive is well-insulated and never open it in the cold.',
        ),
        _FaqItem(
          question: '5. When is the best time to feed the colony?',
          answer: 'Feed them sugar syrup if the app shows a long period of rain or if it\'s early spring and they have no honey stores left.',
        ),
        _FaqItem(
          question: '6. I see bees "fanning" at the entrance, why?',
          answer: 'They are acting like air conditioners! They fan their wings to move hot air out. Check your app; you\'ll likely see the temperature rising.',
        ),
        _FaqItem(
          question: '7. How does the app reduce hive inspections?',
          answer: 'Instead of opening the hive every day and disturbing the bees, you only open it when the app shows something is wrong (like a sudden drop in temp).',
        ),
        _FaqItem(
          question: '8. Where should I place the Smart Bee device?',
          answer: 'The best place is on top of the brood frames, under the inner cover. This gives the most accurate reading of the colony\'s core health.',
        ),
        _FaqItem(
          question: '9. What if my apiary has no Wi-Fi?',
          answer: 'The device needs a connection to send live data. Most farmers use a small 4G/5G mobile router placed in the apiary to cover all hives.',
        ),
        _FaqItem(
          question: '10. Is the device safe from bee propolis?',
          answer: 'Yes, but it\'s best to place it inside a small ventilated plastic case to prevent bees from covering the sensor with wax or propolis.',
        ),
        _FaqItem(
          question: '11. What happens if the internet goes down?',
          answer: 'The device will keep measuring. Once the connection is back, it will sync the latest data to your phone automatically.',
        ),
        _FaqItem(
          question: '12. How accurate is the DHT22 sensor?',
          answer: 'It is highly accurate for beekeeping, measuring temperature within 0.5°C and humidity within 2-5%.',
        ),
        _FaqItem(
          question: '13. Can the device survive rain and heat?',
          answer: 'Since it sits inside the hive, it is protected from rain. It is built to withstand the high natural temperatures of the beehive.',
        ),
        _FaqItem(
          question: '14. Why did my hive card turn "OFFLINE"?',
          answer: 'This means no data has arrived for 30 minutes. The Wi-Fi signal might be too weak or the device disconnected from power.',
        ),
        _FaqItem(
          question: '15. What is the "Admin Access Code"?',
          answer: 'It is a security code (2026) that allows the owner to change settings, manage permissions, and see all hives.',
        ),
        _FaqItem(
          question: '16. How do the "Push Alerts" work?',
          answer: 'If heat or humidity hits a critical level, your phone will ring even if it\'s in your pocket. Ensure notifications and background activity are enabled via the setup popup.',
        ),
        _FaqItem(
          question: '17. Can I see the history of my hive?',
          answer: 'Yes! Tap on any hive card to see a full chart of how the temperature and humidity changed throughout the day.',
        ),
        _FaqItem(
          question: '18. Is my data private?',
          answer: 'Yes, only you and the people you grant permission to can see your hive data through the Smart Bee system.',
        ),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final items = _getFaqItems(context);

    return Scaffold(
      backgroundColor: isDarkMode ? null : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(Lang.t(context, 'faq_guide_title'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: items.length,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 0.5,
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Text('${index + 1}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
              title: Text(
                items[index].question,
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 14, 
                  color: isDarkMode ? AppColors.secondary : Colors.brown[800],
                ),
              ),
              iconColor: AppColors.primary,
              collapsedIconColor: Colors.grey,
              childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: const RoundedRectangleBorder(side: BorderSide.none),
              collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    items[index].answer,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                      height: 1.6,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FaqItem {
  final String question;
  final String answer;
  const _FaqItem({required this.question, required this.answer});
}
