import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../../app/localization/l10n.dart';
import '../../core/errors/app_error.dart';
import '../../core/regions.dart';
import '../../core/widgets/widgets.dart';
import '../auth/session_controller.dart';

class _WeatherPoint {
  final double latitude;
  final double longitude;
  const _WeatherPoint(this.latitude, this.longitude);
}

const _weatherPoints = <String, _WeatherPoint>{
  'Toshkent shahri': _WeatherPoint(41.2995, 69.2401),
  'Toshkent viloyati': _WeatherPoint(41.1, 69.4),
  'Andijon': _WeatherPoint(40.7821, 72.3442),
  'Buxoro': _WeatherPoint(39.7747, 64.4286),
  "Farg'ona": _WeatherPoint(40.3864, 71.7864),
  'Jizzax': _WeatherPoint(40.1158, 67.8422),
  'Xorazm': _WeatherPoint(41.55, 60.63),
  'Namangan': _WeatherPoint(40.9983, 71.6726),
  'Navoiy': _WeatherPoint(40.1039, 65.3688),
  'Qashqadaryo': _WeatherPoint(38.86, 65.79),
  "Qoraqalpog'iston": _WeatherPoint(42.46, 59.61),
  'Samarqand': _WeatherPoint(39.6542, 66.9597),
  'Sirdaryo': _WeatherPoint(40.84, 68.66),
  'Surxondaryo': _WeatherPoint(37.23, 67.28),
};

class AgroWeatherScreen extends ConsumerStatefulWidget {
  const AgroWeatherScreen({super.key});

  @override
  ConsumerState<AgroWeatherScreen> createState() => _AgroWeatherScreenState();
}

class _AgroWeatherScreenState extends ConsumerState<AgroWeatherScreen> {
  late String _region;
  late Future<Map<String, dynamic>> _forecast;
  Position? _position;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    final profileRegion = ref.read(sessionProvider).profile?.region;
    _region = regionsUz.contains(profileRegion) ? profileRegion! : regionsUz.first;
    _forecast = _load(_region);
  }

  Future<Map<String, dynamic>> _load(String region, {Position? position}) async {
    final point = position == null
        ? _weatherPoints[region]!
        : _WeatherPoint(position.latitude, position.longitude);
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '${point.latitude}',
      'longitude': '${point.longitude}',
      'current': 'temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m',
      'daily': 'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max',
      'forecast_days': '5',
      'timezone': 'auto',
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw AppError('error_generic', 'Open-Meteo HTTP ${response.statusCode}');
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic> || decoded['current'] is! Map || decoded['daily'] is! Map) {
      throw const AppError('error_generic');
    }
    return decoded;
  }

  void _changeRegion(String? region) {
    if (region == null || region == _region) return;
    setState(() {
      _region = region;
      _position = null;
      _forecast = _load(region);
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('weather_location_disabled');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw StateError('weather_location_permission');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (!mounted) return;
      setState(() {
        _position = position;
        _forecast = _load(_region, position: position);
      });
    } catch (error) {
      if (mounted) {
        final key = error is StateError ? error.message.toString() : 'error_generic';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr(key))));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  String _weatherCode(BuildContext context, int code) {
    if (code == 0) return context.tr('weather_clear');
    if (code <= 3) return context.tr('weather_cloudy');
    if (code == 45 || code == 48) return context.tr('weather_fog');
    if ([51, 53, 55, 56, 57].contains(code)) return context.tr('weather_drizzle');
    if ([61, 63, 65, 66, 67, 80, 81, 82].contains(code)) return context.tr('weather_rain');
    if ([71, 73, 75, 77, 85, 86].contains(code)) return context.tr('weather_snow');
    if ([95, 96, 99].contains(code)) return context.tr('weather_storm');
    return context.tr('weather_unknown');
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('service_weather')),
        actions: [
          IconButton(
            tooltip: context.tr('weather_use_location'),
            onPressed: _locating ? null : _useCurrentLocation,
            icon: _locating
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: DropdownButtonFormField<String>(
              initialValue: _region,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: context.tr('weather_region'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              items: [
                for (final region in regionsUz)
                  DropdownMenuItem(value: region, child: Text(regionLabel(region, locale))),
              ],
              onChanged: _changeRegion,
            ),
          ),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _forecast,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return ErrorView(error: snapshot.error!, onRetry: () => setState(() => _forecast = _load(_region, position: _position)));
                }
                if (!snapshot.hasData) return const LoadingView();
                final current = snapshot.data!['current'] as Map<String, dynamic>;
                final daily = snapshot.data!['daily'] as Map<String, dynamic>;
                final dates = (daily['time'] as List).cast<String>();
                final codes = (daily['weather_code'] as List).cast<num>();
                final highs = (daily['temperature_2m_max'] as List).cast<num>();
                final lows = (daily['temperature_2m_min'] as List).cast<num>();
                final rain = (daily['precipitation_probability_max'] as List).cast<num>();
                return RefreshIndicator(
                  onRefresh: () async => setState(() => _forecast = _load(_region, position: _position)),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_position == null ? regionLabel(_region, locale) : context.tr('weather_current_location'),
                              style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            Text('${(current['temperature_2m'] as num).round()}°',
                                style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w700)),
                            Text(_weatherCode(context, (current['weather_code'] as num).toInt()),
                                style: Theme.of(context).textTheme.titleMedium),
                            const Divider(height: 24),
                            _WeatherMetric(label: context.tr('weather_feels'), value: '${(current['apparent_temperature'] as num).round()}°'),
                            _WeatherMetric(label: context.tr('weather_humidity'), value: '${current['relative_humidity_2m']}%'),
                            _WeatherMetric(label: context.tr('weather_precipitation'), value: '${current['precipitation']} mm'),
                            _WeatherMetric(label: context.tr('weather_wind'), value: '${current['wind_speed_10m']} km/h'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(context.tr('weather_five_day'), style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      for (var i = 0; i < dates.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(dates[i])),
                                    Text('${highs[i].round()}° / ${lows[i].round()}°'),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(child: Text(_weatherCode(context, codes[i].toInt()))),
                                    Text('${context.tr('weather_rain_short')} ${rain[i]}%'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(context.tr('weather_source_note'), style: Theme.of(context).textTheme.bodySmall),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherMetric extends StatelessWidget {
  final String label;
  final String value;
  const _WeatherMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );
}
