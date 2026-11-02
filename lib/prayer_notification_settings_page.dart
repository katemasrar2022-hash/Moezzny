import 'package:flutter/material.dart';
import 'prayer_notification_service.dart';

const Color _settingsNavy = Color(0xFF0B1220);
const Color _settingsPanel = Color(0xFF151F32);
const Color _settingsGold = Color(0xFFE0B45C);
const Color _settingsMuted = Color(0xFF9BA8BC);

class PrayerNotificationSettingsPage extends StatefulWidget {
  const PrayerNotificationSettingsPage({super.key});

  @override
  State<PrayerNotificationSettingsPage> createState() =>
      _PrayerNotificationSettingsPageState();
}

class _PrayerNotificationSettingsPageState
    extends State<PrayerNotificationSettingsPage> {
  final PrayerNotificationService _service =
      PrayerNotificationService.instance;

  final Map<String, PrayerNotificationSettings> _settings = {};

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      await _service.initialize();

      for (final key in PrayerNotificationService.prayerKeys) {
        _settings[key] = await _service.loadSettings(key);
      }

      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage('تعذر تحميل إعدادات التنبيهات: $error');
    }
  }

  Future<bool> _ensurePermission() async {
    final granted =
        await _service.requestNotificationPermission();

    if (!granted && mounted) {
      _showMessage(
        'لم يتم السماح لمؤذني بإرسال الإشعارات. '
        'يمكنك تفعيل الإذن من إعدادات الهاتف.',
      );
    }

    return granted;
  }

  Future<bool> _ensureExactAlarmPermission() async {
    final granted =
        await _service.requestExactAlarmPermission();

    if (!granted && mounted) {
      _showMessage(
        'إذن المنبهات الدقيقة غير مفعّل. '
        'قد لا تصل التنبيهات في موعدها المحدد. '
        'فعّل الإذن من إعدادات الهاتف ثم حاول مرة أخرى.',
      );
    }

    return granted;
  }

  Future<void> _updateSettings(
    String prayerKey,
    PrayerNotificationSettings updated,
  ) async {
    if (_saving) return;

    final oldSettings =
        await _service.loadSettings(prayerKey);

    if (!mounted) return;

    setState(() {
      _settings[prayerKey] = updated;
      _saving = true;
    });

    try {
      final enabled = updated.adhanEnabled || updated.iqamaEnabled;

      if (enabled) {
        final notificationGranted = await _ensurePermission();

        if (!notificationGranted) {
          if (!mounted) return;

          setState(() {
            _settings[prayerKey] = oldSettings;
          });

          return;
        }

        final exactAlarmGranted =
            await _ensureExactAlarmPermission();

        if (!exactAlarmGranted) {
          if (!mounted) return;

          setState(() {
            _settings[prayerKey] = oldSettings;
          });

          return;
        }
      }

      await _service.saveSettings(prayerKey, updated);

      if (mounted) {
        _showMessage(
          'تم حفظ إعدادات صلاة '
          '${PrayerNotificationService.prayerNames[prayerKey]}',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _settings[prayerKey] = oldSettings;
        });

        _showMessage('تعذر حفظ الإعدادات: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textDirection: TextDirection.rtl,
        ),
        backgroundColor: _settingsPanel,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildPrayerCard(String prayerKey) {
    final settings = _settings[prayerKey] ??
        PrayerNotificationSettings(
          iqamaMinutes:
              PrayerNotificationService.defaultIqamaMinutes[prayerKey] ??
                  15,
        );

    final prayerName =
        PrayerNotificationService.prayerNames[prayerKey] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _settingsPanel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _settingsGold.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.mosque_rounded,
                color: _settingsGold,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'صلاة $prayerName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Divider(
            color: Colors.white12,
            height: 24,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: _settingsGold,
            title: const Text(
              'تنبيه الأذان',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'إشعار عند دخول وقت الصلاة',
              style: TextStyle(color: _settingsMuted),
            ),
            value: settings.adhanEnabled,
            onChanged: _saving
                ? null
                : (value) {
                    _updateSettings(
                      prayerKey,
                      settings.copyWith(adhanEnabled: value),
                    );
                  },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeThumbColor: _settingsGold,
            title: const Text(
              'تذكير الإقامة',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'إشعار بعد الأذان بالمدة المحددة',
              style: TextStyle(color: _settingsMuted),
            ),
            value: settings.iqamaEnabled,
            onChanged: _saving
                ? null
                : (value) {
                    _updateSettings(
                      prayerKey,
                      settings.copyWith(iqamaEnabled: value),
                    );
                  },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'مدة الانتظار للإقامة',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              DropdownButton<int>(
                value: settings.iqamaMinutes,
                dropdownColor: _settingsPanel,
                style: const TextStyle(color: _settingsGold),
                underline: Container(
                  height: 1,
                  color: _settingsGold,
                ),
                items: const [5, 10, 15, 20, 25, 30, 35, 40]
                    .map(
                      (minutes) => DropdownMenuItem<int>(
                        value: minutes,
                        child: Text('$minutes دقيقة'),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (minutes) {
                        if (minutes == null) return;

                        _updateSettings(
                          prayerKey,
                          settings.copyWith(iqamaMinutes: minutes),
                        );
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _settingsNavy,
        appBar: AppBar(
          backgroundColor: _settingsNavy,
          foregroundColor: Colors.white,
          centerTitle: true,
          title: const Text('تنبيهات الصلاة والإقامة'),
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: _settingsGold,
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _settingsPanel,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'خصص تنبيهات الأذان والإقامة لكل صلاة '
                      'بشكل مستقل. يتم حفظ اختياراتك تلقائيًا.',
                      style: TextStyle(
                        color: Colors.white70,
                        height: 1.7,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ...PrayerNotificationService.prayerKeys
                      .map(_buildPrayerCard),
                  if (_saving)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          color: _settingsGold,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  const Text(
                    'ملاحظة: وصول التنبيهات في الوقت المحدد قد '
                    'يتأثر بقيود توفير البطارية وإعدادات الشركة '
                    'المصنّعة للهاتف.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _settingsMuted,
                      fontSize: 12,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
