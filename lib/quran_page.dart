import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const Color _quranNavy = Color(0xFF0B1220);
const Color _quranPanel = Color(0xFF151F32);
const Color _quranGold = Color(0xFFE0B45C);
const Color _quranMuted = Color(0xFF9BA8BC);

class QuranPage extends StatefulWidget {
  const QuranPage({super.key});

  @override
  State<QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends State<QuranPage> {
  late Future<List<_Surah>> _surahsFuture;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _surahsFuture = _loadSurahs();
    _searchController.addListener(() {
      if (mounted) setState(() => _query = _searchController.text.trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<_Surah>> _loadSurahs() async {
    final indexText = await rootBundle.loadString('assets/quran/surah-index.json');
    final quranText = await rootBundle.loadString('assets/quran/quran-uthmani.txt');
    final decoded = jsonDecode(indexText) as Map<String, dynamic>;
    final entries = decoded['surahs'] as List<dynamic>;
    final allLines = const LineSplitter().convert(quranText);

    return entries.map((entry) {
      final item = entry as Map<String, dynamic>;
      final start = item['startLine'] as int;
      final end = item['endLine'] as int;
      if (start < 1 || end < start || end > allLines.length) {
        throw FormatException('بيانات فهرس السور غير متوافقة مع ملف القرآن.');
      }
      return _Surah(
        number: item['number'] as int,
        name: item['name'] as String,
        ayahCount: item['ayahCount'] as int,
        verses: allLines.sublist(start - 1, end),
      );
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _quranNavy,
        appBar: AppBar(
          backgroundColor: _quranNavy,
          foregroundColor: Colors.white,
          title: const Text('القرآن الكريم', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        body: FutureBuilder<List<_Surah>>(
          future: _surahsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator(color: _quranGold));
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.menu_book_rounded, color: _quranGold, size: 48),
                      const SizedBox(height: 14),
                      const Text('تعذر تحميل القرآن الكريم', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('تأكد من وجود ملفات القرآن ضمن أصول التطبيق ثم أعد البناء.', textAlign: TextAlign.center, style: TextStyle(color: _quranMuted)),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => setState(() => _surahsFuture = _loadSurahs()),
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final surahs = snapshot.data!;
            final filtered = surahs.where((s) =>
              s.name.contains(_query) || s.number.toString() == _query
            ).toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _quranPanel,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _quranGold.withValues(alpha: 0.22)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.auto_stories_rounded, color: _quranGold, size: 34),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('كتاب الله الكريم', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              SizedBox(height: 4),
                              Text('114 سورة • قراءة بالرسم العثماني', style: TextStyle(color: _quranMuted, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: TextField(
                    controller: _searchController,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'ابحث باسم السورة أو رقمها',
                      hintStyle: const TextStyle(color: _quranMuted),
                      prefixIcon: const Icon(Icons.search, color: _quranGold),
                      filled: true,
                      fillColor: _quranPanel,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final surah = filtered[index];
                      return Material(
                        color: _quranPanel,
                        borderRadius: BorderRadius.circular(16),
                        child: ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          leading: Container(
                            width: 42,
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: _quranGold.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(12)),
                            child: Text('${surah.number}', style: const TextStyle(color: _quranGold, fontWeight: FontWeight.bold)),
                          ),
                          title: Text(surah.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                          subtitle: Text('${surah.ayahCount} آية', style: const TextStyle(color: _quranMuted, fontSize: 12)),
                          trailing: const Icon(Icons.chevron_left_rounded, color: _quranGold),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QuranReaderPage(surahs: surahs, index: surahs.indexOf(surah)))),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class QuranReaderPage extends StatelessWidget {
  final List<_Surah> surahs;
  final int index;
  const QuranReaderPage({super.key, required this.surahs, required this.index});

  _Surah get surah => surahs[index];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _quranNavy,
        appBar: AppBar(
          backgroundColor: _quranNavy,
          foregroundColor: Colors.white,
          title: Text('سورة ${surah.name}'),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
              decoration: BoxDecoration(color: _quranPanel, borderRadius: BorderRadius.circular(20), border: Border.all(color: _quranGold.withValues(alpha: 0.22))),
              child: Column(
                children: [
                  Text('سورة ${surah.name}', style: const TextStyle(color: _quranGold, fontSize: 23, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('${surah.ayahCount} آية', style: const TextStyle(color: _quranMuted)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: _quranPanel, borderRadius: BorderRadius.circular(20)),
              child: Text.rich(
                TextSpan(children: [
                  for (var i = 0; i < surah.verses.length; i++) ...[
                    TextSpan(text: '${surah.verses[i]} '),
                    TextSpan(text: '﴿${i + 1}﴾ ', style: const TextStyle(color: _quranGold, fontSize: 16)),
                  ],
                ]),
                textAlign: TextAlign.justify,
                textDirection: TextDirection.rtl,
                style: const TextStyle(color: Colors.white, fontSize: 23, height: 2.05, fontFamily: 'Arial'),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                if (surah.number > 1)
                  Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => QuranReaderPage(surahs: surahs, index: index - 1))), icon: const Icon(Icons.arrow_forward), label: const Text('السورة السابقة'))),
                if (surah.number > 1 && surah.number < 114) const SizedBox(width: 10),
                if (surah.number < 114)
                  Expanded(child: FilledButton.icon(onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => QuranReaderPage(surahs: surahs, index: index + 1))), icon: const Icon(Icons.arrow_back), label: const Text('السورة التالية'))),
              ],
            ),
          ],
        ),
      ),
    );
  }

}

class _Surah {
  final int number;
  final String name;
  final int ayahCount;
  final List<String> verses;
  const _Surah({required this.number, required this.name, required this.ayahCount, required this.verses});
}
