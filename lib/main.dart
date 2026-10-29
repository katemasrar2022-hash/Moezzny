
import 'package:flutter/material.dart';

void main() {
  runApp(const MoezznyApp());
}

const Color navy = Color(0xFF0B1220);
const Color panel = Color(0xFF151F32);
const Color gold = Color(0xFFE0B45C);
const Color muted = Color(0xFF9BA8BC);

class MoezznyApp extends StatelessWidget {
  const MoezznyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'مؤذني',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: navy,
        colorScheme: ColorScheme.fromSeed(
          seedColor: gold,
          brightness: Brightness.dark,
          surface: panel,
        ),
        fontFamily: 'Arial',
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int selectedTab = 0;

  final List<Map<String, dynamic>> features = [
    {'icon': Icons.menu_book_rounded, 'title': 'القرآن الكريم', 'sub': 'وردك اليومي'},
    {'icon': Icons.explore_rounded, 'title': 'القبلة', 'sub': 'اتجاه القبلة'},
    {'icon': Icons.favorite_rounded, 'title': 'الأذكار', 'sub': 'حصن المسلم'},
    {'icon': Icons.calendar_month_rounded, 'title': 'التقويم الهجري', 'sub': 'المناسبات الإسلامية'},
    {'icon': Icons.mosque_rounded, 'title': 'المساجد', 'sub': 'المساجد القريبة'},
    {'icon': Icons.notifications_active_rounded, 'title': 'التنبيهات', 'sub': 'إعدادات الأذان'},
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: gold.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: gold.withValues(alpha: 0.4)),
                        ),
                        child: const Icon(Icons.mosque_rounded, color: gold, size: 28),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('مُؤذني', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: Colors.white)),
                            SizedBox(height: 3),
                            Text('رفيقك في كل صلاة', style: TextStyle(color: muted, fontSize: 13)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _message('الإشعارات ستتوفر مع إعدادات الأذان.'),
                        icon: const Icon(Icons.notifications_none_rounded, color: gold, size: 28),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF202F49), Color(0xFF111A2B)],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: gold.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.wb_twilight_rounded, color: gold, size: 24),
                            SizedBox(width: 8),
                            Text('السَّلامُ عَلَيْكُم', style: TextStyle(color: gold, fontSize: 15)),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const Text('حافظ على صلاتك', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: Colors.white)),
                        const SizedBox(height: 8),
                        const Text('اجعل صلاتك وذكرك نور يومك.', style: TextStyle(fontSize: 14, color: muted)),
                        const SizedBox(height: 22),
                        Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.access_time_rounded, color: gold, size: 26),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('الصلاة القادمة', style: TextStyle(color: muted, fontSize: 12)),
                                    SizedBox(height: 5),
                                    Text(
  prayerTimes == null
      ? locationMessage
      : '${arabicPrayerName(nextPrayer)} - '
          '${formatPrayerTime(
            prayerTimes!.getNextPrayer() ?? prayerTimes!.fajr,
          )}',
  style: const TextStyle(
    color: Colors.white,
    fontSize: 15,
    fontWeight: FontWeight.w600,
  ),
),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_back_ios_new_rounded, color: gold, size: 16),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('مواقيت الصلاة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                      TextButton(
                        onPressed: () => _message('سنضيف الحساب الفعلي لمواقيت الصلاة في المرحلة التالية.'),
                        child: const Text('التفاصيل', style: TextStyle(color: gold)),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
                    decoration: BoxDecoration(
                      color: panel,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        PrayerItem(name: 'الفجر', time: '--:--', icon: Icons.nights_stay_rounded),
                        PrayerItem(name: 'الظهر', time: '--:--', icon: Icons.wb_sunny_rounded),
                        PrayerItem(name: 'العصر', time: '--:--', icon: Icons.sunny_snowing),
                        PrayerItem(name: 'المغرب', time: '--:--', icon: Icons.wb_twilight_rounded),
                        PrayerItem(name: 'العشاء', time: '--:--', icon: Icons.dark_mode_rounded),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
                sliver: SliverToBoxAdapter(
                  child: const Text('اكتشف مؤذني', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.42,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = features[index];
                      return InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _message('قسم ${item['title']} سنعمل على تفعيله في الخطوات القادمة.'),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: panel,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(item['icon'] as IconData, color: gold, size: 28),
                              const SizedBox(height: 12),
                              Text(item['title'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                              const SizedBox(height: 4),
                              Text(item['sub'] as String, style: const TextStyle(color: muted, fontSize: 11)),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: features.length,
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          backgroundColor: const Color(0xFF101827),
          indicatorColor: gold.withValues(alpha: 0.18),
          selectedIndex: selectedTab,
          onDestinationSelected: (index) {
            setState(() => selectedTab = index);
            if (index != 0) {
              _message(['الرئيسية', 'القرآن الكريم', 'الأذكار', 'الإعدادات'][index]);
            }
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_rounded), label: 'الرئيسية'),
            NavigationDestination(icon: Icon(Icons.menu_book_rounded), label: 'القرآن'),
            NavigationDestination(icon: Icon(Icons.favorite_rounded), label: 'الأذكار'),
            NavigationDestination(icon: Icon(Icons.settings_rounded), label: 'الإعدادات'),
          ],
        ),
      ),
    );
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor: panel,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class PrayerItem extends StatelessWidget {
  final String name;
  final String time;
  final IconData icon;

  const PrayerItem({
    super.key,
    required this.name,
    required this.time,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: gold, size: 22),
        const SizedBox(height: 9),
        Text(name, style: const TextStyle(color: muted, fontSize: 11)),
        const SizedBox(height: 6),
        Text(time, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }
}
