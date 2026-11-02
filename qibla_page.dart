import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color _navy = Color(0xFF0B1220);
const Color _panel = Color(0xFF151F32);
const Color _gold = Color(0xFFE0B45C);
const Color _muted = Color(0xFF9BA8BC);
const double _kaabaLat = 21.422487;
const double _kaabaLon = 39.826206;

class _QiblaPlace {
  final String name;
  final double lat;
  final double lon;
  const _QiblaPlace(this.name, this.lat, this.lon);
}

const List<_QiblaPlace> _places = [
  _QiblaPlace('القاهرة', 30.0444, 31.2357),
  _QiblaPlace('الإسكندرية', 31.2001, 29.9187),
  _QiblaPlace('الجيزة', 30.0131, 31.2089),
  _QiblaPlace('طنطا', 30.7865, 31.0004),
  _QiblaPlace('المنصورة', 31.0409, 31.3785),
  _QiblaPlace('الزقازيق', 30.5877, 31.5020),
  _QiblaPlace('أسيوط', 27.1809, 31.1837),
  _QiblaPlace('الأقصر', 25.6872, 32.6396),
  _QiblaPlace('أسوان', 24.0889, 32.8998),
  _QiblaPlace('العريش', 31.1316, 33.7984),
  _QiblaPlace('شرم الشيخ', 27.9158, 34.3299),
  _QiblaPlace('مكة المكرمة', 21.3891, 39.8579),
  _QiblaPlace('المدينة المنورة', 24.4672, 39.6111),
  _QiblaPlace('الرياض', 24.7136, 46.6753),
  _QiblaPlace('جدة', 21.4858, 39.1925),
  _QiblaPlace('دبي', 25.2048, 55.2708),
  _QiblaPlace('أبوظبي', 24.4539, 54.3773),
  _QiblaPlace('الدوحة', 25.2854, 51.5310),
  _QiblaPlace('الكويت', 29.3759, 47.9774),
  _QiblaPlace('عمّان', 31.9539, 35.9106),
  _QiblaPlace('القدس', 31.7683, 35.2137),
  _QiblaPlace('بيروت', 33.8938, 35.5018),
  _QiblaPlace('دمشق', 33.5138, 36.2765),
  _QiblaPlace('بغداد', 33.3152, 44.3661),
  _QiblaPlace('الخرطوم', 15.5007, 32.5599),
  _QiblaPlace('طرابلس', 32.8872, 13.1913),
  _QiblaPlace('تونس', 36.8065, 10.1815),
  _QiblaPlace('الجزائر', 36.7538, 3.0588),
  _QiblaPlace('الدار البيضاء', 33.5731, -7.5898),
  _QiblaPlace('إسطنبول', 41.0082, 28.9784),
];

class QiblaPage extends StatefulWidget {
  const QiblaPage({super.key});

  @override
  State<QiblaPage> createState() => _QiblaPageState();
}

class _QiblaPageState extends State<QiblaPage> {
  double? _latitude;
  double? _longitude;
  double? _heading;
  double? _qiblaBearing;
  String _placeName = 'جارٍ تحديد الموقع';
  String _status = 'حدد موقعك تلقائيًا أو اختر مدينتك يدويًا';
  bool _loading = true;
  bool _manual = false;
  StreamSubscription<CompassEvent>? _compassSubscription;

  @override
  void initState() {
    super.initState();
    _listenToCompass();
    _loadSavedPlace();
  }

  @override
  void dispose() {
    _compassSubscription?.cancel();
    super.dispose();
  }

  void _listenToCompass() {
    final events = FlutterCompass.events;
    if (events == null) {
      setStateIfMounted(
        () => _status = 'حساس البوصلة غير متاح على هذا الهاتف',
      );
      return;
    }

    _compassSubscription = events.listen((event) {
      if (!mounted) return;
      setState(() => _heading = event.heading);
    });
  }

  void setStateIfMounted(VoidCallback callback) {
    if (mounted) setState(callback);
  }

  Future<void> _loadSavedPlace() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('qibla_latitude');
    final lon = prefs.getDouble('qibla_longitude');
    final name = prefs.getString('qibla_place_name');
    final manual = prefs.getBool('qibla_manual') ?? false;

    if (lat != null && lon != null && name != null) {
      _setPlace(lat, lon, name, manual: manual, save: false);
    } else {
      await useCurrentLocation();
    }

    if (mounted) setState(() => _loading = false);
  }

  void _setPlace(
    double lat,
    double lon,
    String name, {
    required bool manual,
    bool save = true,
  }) {
    if (!mounted) return;

    setState(() {
      _latitude = lat;
      _longitude = lon;
      _placeName = name;
      _manual = manual;
      _qiblaBearing = _bearingToKaaba(lat, lon);
      _status = manual ? 'تم اختيار الموقع يدويًا' : 'تم تحديد موقعك';
    });

    if (save) _savePlace(lat, lon, name, manual);
  }

  Future<void> _savePlace(
    double lat,
    double lon,
    String name,
    bool manual,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('qibla_latitude', lat);
    await prefs.setDouble('qibla_longitude', lon);
    await prefs.setString('qibla_place_name', name);
    await prefs.setBool('qibla_manual', manual);
  }

  Future<void> useCurrentLocation() async {
    setStateIfMounted(() {
      _loading = true;
      _status = 'جارٍ تحديد موقعك...';
    });

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        throw Exception('فعّل خدمة GPS ثم حاول مرة أخرى');
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception(
          'اسمح لمؤذني بالوصول إلى الموقع من إعدادات الهاتف',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 25),
        ),
      );

      _setPlace(
        position.latitude,
        position.longitude,
        'موقعي الحالي',
        manual: false,
      );
    } catch (e) {
      setStateIfMounted(
        () => _status = e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      setStateIfMounted(() => _loading = false);
    }
  }

  double _bearingToKaaba(double lat, double lon) {
    final phi1 = _radians(lat);
    final phi2 = _radians(_kaabaLat);
    final deltaLambda = _radians(_kaabaLon - lon);

    final y = math.sin(deltaLambda);
    final x = math.cos(phi1) * math.tan(phi2) -
        math.sin(phi1) * math.cos(deltaLambda);

    return (_degrees(math.atan2(y, x)) + 360) % 360;
  }

  double _radians(double value) => value * math.pi / 180;

  double _degrees(double value) => value * 180 / math.pi;

  String _directionName(double degrees) {
    const directions = [
      'شمال',
      'شمال شرق',
      'شرق',
      'جنوب شرق',
      'جنوب',
      'جنوب غرب',
      'غرب',
      'شمال غرب',
    ];

    return directions[((degrees + 22.5) ~/ 45) % 8];
  }

  Future<void> _chooseCity() async {
    final controller = TextEditingController();

    final selected = await showModalBottomSheet<_QiblaPlace>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final query = controller.text.trim();

            final results = _places
                .where((p) => p.name.contains(query))
                .toList();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 18,
                  right: 18,
                  top: 18,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 18,
                ),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.68,
                  child: Column(
                    children: [
                      const Text(
                        'اختيار المدينة',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: controller,
                        onChanged: (_) => setSheetState(() {}),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'ابحث عن مدينة',
                          hintStyle: const TextStyle(color: _muted),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: _gold,
                          ),
                          filled: true,
                          fillColor: _navy,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: results.isEmpty
                            ? const Center(
                                child: Text(
                                  'لا توجد مدينة مطابقة',
                                  style: TextStyle(color: _muted),
                                ),
                              )
                            : ListView.builder(
                                itemCount: results.length,
                                itemBuilder: (_, i) => ListTile(
                                  title: Text(
                                    results[i].name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                    ),
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_left,
                                    color: _gold,
                                  ),
                                  onTap: () => Navigator.pop(
                                    sheetContext,
                                    results[i],
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    controller.dispose();

    if (selected != null) {
      _setPlace(
        selected.lat,
        selected.lon,
        selected.name,
        manual: true,
      );
    }
  }

  Future<void> _enterCoordinates() async {
    final latController = TextEditingController();
    final lonController = TextEditingController();
    final nameController = TextEditingController(text: 'موقع مخصص');
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<_QiblaPlace>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _panel,
        title: const Text(
          'إدخال إحداثيات الموقع',
          style: TextStyle(color: Colors.white),
        ),
        content: Form(
          key: formKey,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _coordinateField(
                    nameController,
                    'اسم الموقع',
                    allowName: true,
                  ),
                  const SizedBox(height: 10),
                  _coordinateField(
                    latController,
                    'خط العرض (Latitude)',
                  ),
                  const SizedBox(height: 10),
                  _coordinateField(
                    lonController,
                    'خط الطول (Longitude)',
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final lat = double.tryParse(latController.text.trim());
              final lon = double.tryParse(lonController.text.trim());

              if (formKey.currentState!.validate() &&
                  lat != null &&
                  lon != null &&
                  lat >= -90 &&
                  lat <= 90 &&
                  lon >= -180 &&
                  lon <= 180) {
                Navigator.pop(
                  dialogContext,
                  _QiblaPlace(
                    nameController.text.trim(),
                    lat,
                    lon,
                  ),
                );
              } else if (lat != null && lon != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('الإحداثيات خارج النطاق الصحيح'),
                  ),
                );
              }
            },
            child: const Text('حفظ الموقع'),
          ),
        ],
      ),
    );

    latController.dispose();
    lonController.dispose();
    nameController.dispose();

    if (result != null) {
      _setPlace(
        result.lat,
        result.lon,
        result.name,
        manual: true,
      );
    }
  }

  Widget _coordinateField(
    TextEditingController controller,
    String label, {
    bool allowName = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: allowName
          ? TextInputType.text
          : const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _muted),
        filled: true,
        fillColor: _navy,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'هذا الحقل مطلوب';
        }

        if (!allowName && double.tryParse(value.trim()) == null) {
          return 'أدخل رقمًا صحيحًا';
        }

        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bearing = _qiblaBearing;
    final heading = _heading;

    final relativeAngle = bearing != null && heading != null
        ? bearing - heading
        : (bearing ?? 0);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _navy,
        appBar: AppBar(
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          centerTitle: true,
          title: const Text(
            'اتجاه القبلة',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: _loading && bearing == null
            ? const Center(
                child: CircularProgressIndicator(color: _gold),
              )
            : ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _panel,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: _gold.withValues(alpha: .25),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'اتجه نحو الكعبة المشرفة',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _placeName,
                          style: const TextStyle(color: _muted),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: 270,
                          height: 270,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _gold.withValues(alpha: .65),
                                    width: 2,
                                  ),
                                  gradient: RadialGradient(
                                    colors: [_panel, _navy],
                                  ),
                                ),
                              ),
                              for (int i = 0; i < 4; i++)
                                Transform.rotate(
                                  angle: i * math.pi / 2,
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child: Container(
                                      margin: const EdgeInsets.only(top: 12),
                                      width: 2,
                                      height: 15,
                                      color: _muted,
                                    ),
                                  ),
                                ),
                              const Positioned(
                                top: 16,
                                child: Text(
                                  'ش',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Positioned(
                                child: Transform.rotate(
                                  angle: _radians(relativeAngle),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.navigation_rounded,
                                        color: _gold,
                                        size: 78,
                                      ),
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: _gold,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          bearing == null
                              ? '--°'
                              : '${bearing.toStringAsFixed(1)}°',
                          style: const TextStyle(
                            color: _gold,
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          bearing == null
                              ? 'لم يتم تحديد الاتجاه'
                              : 'من الشمال • ${_directionName(bearing)}',
                          style: const TextStyle(color: _muted),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          heading == null
                              ? 'حساس البوصلة غير متاح أو لم يرسل قراءة بعد'
                              : 'اتجاه الهاتف: ${heading.toStringAsFixed(0)}°',
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _panel,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: _gold),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _status,
                            style: const TextStyle(color: _muted),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _loading ? null : useCurrentLocation,
                    icon: const Icon(Icons.my_location_rounded),
                    label: const Text('استخدام موقعي الحالي تلقائيًا'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: _navy,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _chooseCity,
                    icon: const Icon(Icons.location_city_rounded),
                    label: const Text('اختيار المدينة يدويًا'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: _gold),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _enterCoordinates,
                    icon: const Icon(Icons.pin_drop_outlined),
                    label: const Text('إدخال الإحداثيات يدويًا'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: .25),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'تنبيه: للحصول على قراءة أدق، أبعد الهاتف عن المعادن والمغناطيس، وحرّكه برفق على شكل رقم 8 إذا كانت البوصلة غير مستقرة.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _muted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
