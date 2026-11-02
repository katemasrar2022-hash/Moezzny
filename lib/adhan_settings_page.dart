import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color _adhanNavy = Color(0xFF0B1220);
const Color _adhanPanel = Color(0xFF151F32);
const Color _adhanGold = Color(0xFFE0B45C);
const String _adhanLibraryKey = 'moezzny_adhan_audio_library_v1';
const String _adhanSelectedKey = 'moezzny_selected_adhan_id';

class AdhanSettingsPage extends StatefulWidget {
  const AdhanSettingsPage({super.key});

  @override
  State<AdhanSettingsPage> createState() => _AdhanSettingsPageState();
}

class _AdhanSettingsPageState extends State<AdhanSettingsPage> {
  final AudioPlayer _player = AudioPlayer();
  final List<Map<String, String>> _sounds = [];
  String? _selectedId;
  String? _playingId;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadSounds();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadSounds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_adhanLibraryKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _sounds
          ..clear()
          ..addAll(decoded.map(
            (item) => Map<String, String>.from(item as Map),
          ));
      } catch (_) {
        _sounds.clear();
      }
    }
    _selectedId = prefs.getString(_adhanSelectedKey);
    if (_selectedId != null &&
        !_sounds.any((sound) => sound['id'] == _selectedId)) {
      _selectedId = null;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveSounds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_adhanLibraryKey, jsonEncode(_sounds));
    if (_selectedId == null) {
      await prefs.remove(_adhanSelectedKey);
    } else {
      await prefs.setString(_adhanSelectedKey, _selectedId!);
    }
  }

  Future<void> _addFromPhone() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'aac', 'wav', 'ogg'],
    );
    if (files.isEmpty) return;

    final picked = files.single;
    final sourcePath = picked.path;
    if (sourcePath == null) {
      _showMessage('تعذر الوصول إلى الملف المختار.');
      return;
    }

    setState(() => _busy = true);
    try {
      final appDirectory = await getApplicationDocumentsDirectory();
      final audioDirectory = Directory('${appDirectory.path}/adhan_audio');
      if (!await audioDirectory.exists()) {
        await audioDirectory.create(recursive: true);
      }

      final extension = picked.extension ?? 'mp3';
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      final destination = '${audioDirectory.path}/$id.$extension';
      await File(sourcePath).copy(destination);

      final name = picked.name.replaceAll(RegExp(r'\.[^.]+$'), '');
      _sounds.add({
        'id': id,
        'name': name.isEmpty ? 'أذان من الهاتف' : name,
        'source': 'file',
        'path': destination,
      });
      await _saveSounds();
      if (mounted) setState(() {});
      _showMessage('تمت إضافة الصوت إلى مكتبتك.');
    } catch (error) {
      _showMessage('تعذرت إضافة الملف: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addFromUrl() async {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _adhanPanel,
          title: const Text('إضافة صوت من الإنترنت'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'اسم الصوت'),
                  validator: (value) =>
                      value == null || value.trim().isEmpty
                          ? 'اكتب اسمًا للصوت'
                          : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: urlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'رابط مباشر لملف الصوت',
                    hintText: 'https://example.com/adhan.mp3',
                  ),
                  validator: (value) {
                    final uri = Uri.tryParse((value ?? '').trim());
                    if (uri == null ||
                        (uri.scheme != 'https' && uri.scheme != 'http') ||
                        uri.host.isEmpty) {
                      return 'أدخل رابط HTTP أو HTTPS صحيحًا';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );

    if (accepted == true) {
      final uri = Uri.parse(urlController.text.trim());
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      _sounds.add({
        'id': id,
        'name': nameController.text.trim(),
        'source': 'url',
        'url': uri.toString(),
      });
      await _saveSounds();
      if (mounted) setState(() {});
      _showMessage('تم حفظ الرابط. شغّل الصوت للتأكد من صلاحيته.');
    }
    nameController.dispose();
    urlController.dispose();
  }

  Future<void> _togglePlayback(Map<String, String> sound) async {
    final id = sound['id']!;
    if (_playingId == id) {
      await _player.stop();
      if (mounted) setState(() => _playingId = null);
      return;
    }

    try {
      await _player.stop();
      if (sound['source'] == 'file') {
        await _player.setFilePath(sound['path']!);
      } else {
        await _player.setUrl(sound['url']!);
      }
      if (mounted) setState(() => _playingId = id);
      await _player.play();
      if (mounted && _playingId == id) {
        setState(() => _playingId = null);
      }
    } catch (_) {
      if (mounted) setState(() => _playingId = null);
      _showMessage('تعذر تشغيل الصوت. تحقق من الملف أو الرابط المباشر.');
    }
  }

  Future<void> _selectSound(String id) async {
    setState(() => _selectedId = id);
    await _saveSounds();
    _showMessage('تم اختيار هذا الصوت كصوت الأذان الافتراضي.');
  }

  Future<void> _deleteSound(Map<String, String> sound) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _adhanPanel,
          title: const Text('حذف الصوت؟'),
          content: Text('سيتم حذف «${sound['name'] ?? ''}» من مكتبتك.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('حذف'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    if (_playingId == sound['id']) {
      await _player.stop();
      _playingId = null;
    }
    if (sound['source'] == 'file') {
      final file = File(sound['path']!);
      if (await file.exists()) await file.delete();
    }
    _sounds.removeWhere((item) => item['id'] == sound['id']);
    if (_selectedId == sound['id']) _selectedId = null;
    await _saveSounds();
    if (mounted) setState(() {});
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor: _adhanPanel,
      ),
    );
  }

  Widget _addButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: _busy ? null : onPressed,
      icon: Icon(icon, color: _adhanGold),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: _adhanGold.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _adhanNavy,
        appBar: AppBar(
          backgroundColor: _adhanNavy,
          foregroundColor: Colors.white,
          centerTitle: true,
          title: const Text('أصوات الأذان'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _adhanGold))
            : ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _adhanPanel,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _adhanGold.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مكتبة أذانك',
                          style: TextStyle(
                            color: _adhanGold,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'أضف ملفات الأذان من هاتفك أو رابط MP3 مباشر، واستمع إليها قبل اختيار الصوت الافتراضي. في هذه المرحلة لن يعمل الأذان تلقائيًا عند الصلاة.',
                          style: TextStyle(
                            color: Colors.white70,
                            height: 1.7,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _addButton(
                          icon: Icons.phone_android_rounded,
                          label: 'من الهاتف',
                          onPressed: _addFromPhone,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _addButton(
                          icon: Icons.link_rounded,
                          label: 'من رابط',
                          onPressed: _addFromUrl,
                        ),
                      ),
                    ],
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 14),
                    const LinearProgressIndicator(color: _adhanGold),
                  ],
                  const SizedBox(height: 22),
                  const Text(
                    'الأصوات المضافة',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_sounds.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _adhanPanel,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Text(
                        'لم تضف أصواتًا بعد. اختر ملف أذان من هاتفك أو أضف رابطًا مباشرًا.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          height: 1.7,
                        ),
                      ),
                    ),
                  ..._sounds.map((sound) {
                    final id = sound['id']!;
                    final selected = _selectedId == id;
                    final playing = _playingId == id;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _adhanPanel,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: selected ? _adhanGold : Colors.white12,
                        ),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: playing ? 'إيقاف' : 'استماع',
                            onPressed: () => _togglePlayback(sound),
                            icon: Icon(
                              playing
                                  ? Icons.stop_circle
                                  : Icons.play_circle,
                              color: _adhanGold,
                              size: 34,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sound['name'] ?? 'صوت أذان',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  sound['source'] == 'file'
                                      ? 'ملف محفوظ على الجهاز'
                                      : 'رابط من الإنترنت',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                                if (selected)
                                  const Text(
                                    'الصوت الافتراضي',
                                    style: TextStyle(
                                      color: _adhanGold,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: selected ? 'محدد' : 'اختيار افتراضي',
                            onPressed: selected ? null : () => _selectSound(id),
                            icon: Icon(
                              selected
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: _adhanGold,
                            ),
                          ),
                          IconButton(
                            tooltip: 'حذف',
                            onPressed: () => _deleteSound(sound),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  const Text(
                    'يمكنك إضافة تسجيلات الأذان المصري أو الحرم المكي أو المسجد النبوي أو غيرها عند توفر ملفات تملك حق استخدامها. لم نضمّن تسجيلات غير موثقة الحقوق.',
                    style: TextStyle(
                      color: Colors.white54,
                      height: 1.6,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
