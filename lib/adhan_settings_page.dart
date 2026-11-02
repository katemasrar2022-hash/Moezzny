import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _bundledAdhanAsset = 'assets/adhan/default_adhan.mp3';

const Color _adhanNavy = Color(0xFF0B1220);
const Color _adhanPanel = Color(0xFF151F32);
const Color _adhanGold = Color(0xFFE0B45C);

const String _adhanLibraryKey = 'moezzny_adhan_audio_library_v1';
const String _adhanSelectedKey = 'moezzny_selected_adhan_id';
const String _bundledAdhanId = 'moezzny_bundled_adhan_cc0_v1';

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
          ..addAll(
            decoded.map(
              (item) => Map<String, String>.from(item as Map),
            ),
          );
      } catch (_) {
        _sounds.clear();
      }
    }

    if (!_sounds.any((sound) => sound['id'] == _bundledAdhanId)) {
      _sounds.insert(0, {
        'id': _bundledAdhanId,
        'name': 'أذان افتراضي - تسجيل مجاني',
        'source': 'asset',
        'path': _bundledAdhanAsset,
      });

      await prefs.setString(
        _adhanLibraryKey,
        jsonEncode(_sounds),
      );
    } else {
      // تحديث مسار الصوت الافتراضي إذا كان محفوظًا بالمسار القديم.
      final bundledIndex = _sounds.indexWhere(
        (sound) => sound['id'] == _bundledAdhanId,
      );

      _sounds[bundledIndex]['path'] = _bundledAdhanAsset;
      _sounds[bundledIndex]['source'] = 'asset';

      await prefs.setString(
        _adhanLibraryKey,
        jsonEncode(_sounds),
      );
    }

    _selectedId = prefs.getString(_adhanSelectedKey);

    if (_selectedId == null ||
        !_sounds.any((sound) => sound['id'] == _selectedId)) {
      _selectedId = _bundledAdhanId;

      await prefs.setString(
        _adhanSelectedKey,
        _selectedId!,
      );
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveSounds() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _adhanLibraryKey,
      jsonEncode(_sounds),
    );

    if (_selectedId == null) {
      await prefs.remove(_adhanSelectedKey);
    } else {
      await prefs.setString(
        _adhanSelectedKey,
        _selectedId!,
      );
    }
  }

  Future<void> _addFromPhone() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'aac', 'wav', 'ogg'],
    );

    if (files == null || files.isEmpty) return;

    final picked = files.single;
    final sourcePath = picked.path;

    if (sourcePath == null) {
      _showMessage('تعذر الوصول إلى الملف المختار.');
      return;
    }

    setState(() => _busy = true);

    try {
      final appDirectory = await getApplicationDocumentsDirectory();

      final audioDirectory = Directory(
        '${appDirectory.path}/adhan_audio',
      );

      if (!await audioDirectory.exists()) {
        await audioDirectory.create(recursive: true);
      }

      final extension = picked.extension ?? 'mp3';
      final id = DateTime.now().microsecondsSinceEpoch.toString();

      final destination =
          '${audioDirectory.path}/$id.$extension';

      await File(sourcePath).copy(destination);

      final name = picked.name.replaceAll(
        RegExp(r'\.[^.]+$'),
        '',
      );

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
      if (mounted) {
        setState(() => _busy = false);
      }
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
                  decoration: const InputDecoration(
                    labelText: 'اسم الصوت',
                  ),
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
                    final uri = Uri.tryParse(
                      (value ?? '').trim(),
                    );

                    if (uri == null ||
                        (uri.scheme != 'https' &&
                            uri.scheme != 'http') ||
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
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
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

      _showMessage(
        'تم حفظ الرابط. شغّل الصوت للتأكد من صلاحيته.',
      );
    }

    nameController.dispose();
    urlController.dispose();
  }

  Future<void> _togglePlayback(
    Map<String, String> sound,
  ) async {
    final id = sound['id']!;

    if (_playingId == id) {
      await _player.stop();

      if (mounted) {
        setState(() => _playingId = null);
      }

      return;
    }

    try {
      await _player.stop();

      if (sound['source'] == 'file') {
        await _player.setFilePath(sound['path']!);
      } else if (sound['source'] == 'asset') {
        await _player.setAsset(sound['path']!);
      } else {
        await _player.setUrl(sound['url']!);
      }

      if (mounted) {
        setState(() => _playingId = id);
      }

      await _player.play();

      if (mounted && _playingId == id) {
        setState(() => _playingId = null);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _playingId = null);
      }

      _showMessage(
        'تعذر تشغيل الصوت. تحقق من الملف أو الرابط المباشر.',
      );
    }
  }

  Future<void> _selectSound(String id) async {
    setState(() => _selectedId = id);

    await _saveSounds();

    _showMessage(
      'تم اختيار هذا الصوت كصوت الأذان الافتراضي.',
    );
  }

  Future<void> _deleteSound(
    Map<String, String> sound,
  Future<void> _togglePlayback(
  Map<String, String> sound,
) async {
  final id = sound['id']!;

  if (_playingId == id) {
    await _player.stop();

    if (mounted) {
      setState(() => _playingId = null);
    }

    return;
  }

  try {
    await _player.stop();

    if (sound['source'] == 'file') {
      final path = sound['path']!;

      if (!await File(path).exists()) {
        throw Exception('ملف الصوت غير موجود: $path');
      }

      await _player.setFilePath(path);
    } else if (sound['source'] == 'asset') {
      await _player.setAsset(_bundledAdhanAsset);
    } else {
      await _player.setUrl(sound['url']!);
    }

    if (mounted) {
      setState(() => _playingId = id);
    }

    await _player.play();

    if (mounted && _playingId == id) {
      setState(() => _playingId = null);
    }
  } catch (error, stackTrace) {
    debugPrint('ADHAN PLAYBACK ERROR: $error');
    debugPrintStack(stackTrace: stackTrace);

    if (mounted) {
      setState(() => _playingId = null);
    }

    _showMessage('خطأ تشغيل الأذان: $error');
  }
}

    _sounds.removeWhere(
      (item) => item['id'] == id,
    );

    if (_selectedId == id) {
      _selectedId = _bundledAdhanId;
    }

    await _saveSounds();

    if (mounted) setState(() {});

    _showMessage('تم حذف الصوت.');
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _adhanPanel,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildSoundCard(
    Map<String, String> sound,
  ) {
    final id = sound['id']!;
    final selected = id == _selectedId;
    final playing = id == _playingId;
    final bundled = id == _bundledAdhanId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _adhanPanel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? _adhanGold : Colors.white12,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _adhanGold.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.volume_up_rounded,
                  color: _adhanGold,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sound['name'] ?? 'صوت أذان',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      bundled
                          ? 'صوت افتراضي'
                          : sound['source'] == 'url'
                              ? 'من الإنترنت'
                              : 'من الهاتف',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle,
                  color: _adhanGold,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _togglePlayback(sound),
                  icon: Icon(
                    playing
                        ? Icons.stop
                        : Icons.play_arrow,
                  ),
                  label: Text(
                    playing ? 'إيقاف' : 'استماع',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _adhanGold,
                    side: const BorderSide(
                      color: _adhanGold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: selected
                      ? null
                      : () => _selectSound(id),
                  icon: const Icon(Icons.check),
                  label: const Text('اختيار'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _adhanGold,
                    foregroundColor: _adhanNavy,
                    disabledBackgroundColor: Colors.white12,
                    disabledForegroundColor: Colors.white54,
                  ),
                ),
              ),
              if (!bundled) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => _deleteSound(sound),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton({
    required IconData icon,
    required String title,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: _busy ? null : onPressed,
        icon: Icon(icon),
        label: Text(title),
        style: OutlinedButton.styleFrom(
          foregroundColor: _adhanGold,
          side: const BorderSide(color: _adhanGold),
          padding: const EdgeInsets.symmetric(vertical: 13),
        ),
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
          elevation: 0,
          title: const Text(
            'أصوات الأذان',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: _adhanGold,
                ),
              )
            : SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _adhanPanel,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.mosque_rounded,
                            color: _adhanGold,
                            size: 34,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'اختر صوت الأذان',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 7),
                          Text(
                            'أضف أصواتك المفضلة، واستمع إليها، '
                            'واختر الصوت الذي تريد استخدامه.',
                            style: TextStyle(
                              color: Colors.white70,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'مكتبة الأصوات',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._sounds.map(_buildSoundCard),
                    const SizedBox(height: 12),
                    if (_busy)
                      const Center(
                        child: CircularProgressIndicator(
                          color: _adhanGold,
                        ),
                      ),
                    Row(
                      children: [
                        _buildAddButton(
                          icon: Icons.phone_android,
                          title: 'من الهاتف',
                          onPressed: _addFromPhone,
                        ),
                        const SizedBox(width: 10),
                        _buildAddButton(
                          icon: Icons.link,
                          title: 'من رابط',
                          onPressed: _addFromUrl,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'ملحوظة: يجب أن يكون الرابط مباشرًا لملف صوت '
                      'وليس رابط صفحة ويب.',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
