import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/models/location.dart';
import '../theme.dart';

class LocationCard extends StatelessWidget {
  final StoreLocation location;

  const LocationCard({super.key, required this.location});

  /// Hoja de acciones del diseño: llamar, copiar teléfono y abrir mapa.
  void _showActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                location.name.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: CelfixColors.blue,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              if (location.phone != null) ...[
                FilledButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _call(context);
                  },
                  child: const Text('LLAMAR'),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await Clipboard.setData(
                        ClipboardData(text: location.phone!));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Teléfono copiado: ${location.phone}')),
                      );
                    }
                  },
                  child: const Text('COPIAR TELÉFONO'),
                ),
                const SizedBox(height: 12),
              ],
              if (location.mapsUrl != null)
                FilledButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _openMaps(context);
                  },
                  child: const Text('ABRIR MAPA'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// `maps_url` viene pre-construido del backend — no lo armamos en cliente.
  Future<void> _openMaps(BuildContext context) async {
    final url = location.mapsUrl;
    if (url == null) return;
    final launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el mapa.')),
      );
    }
  }

  Future<void> _call(BuildContext context) async {
    final phone = location.phone;
    if (phone == null) return;
    if (!await launchUrl(Uri(scheme: 'tel', path: phone)) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Marca al $phone')),
      );
    }
  }

  /// Agrupa los días con el mismo horario: "L - V: 09:00 - 18:00".
  List<String> _scheduleLines() {
    const weekdays = ['mon', 'tue', 'wed', 'thu', 'fri'];
    final lines = <String>[];

    final weekdayHours =
        weekdays.map((day) => location.hours[day]?.label).toList();
    final allSame = weekdayHours.every((label) => label == weekdayHours.first);
    if (weekdayHours.first != null && allSame) {
      lines.add('L - V:  ${weekdayHours.first}');
    } else {
      for (final day in weekdays) {
        final hours = location.hours[day];
        if (hours != null) {
          lines.add('${StoreLocation.dayLabels[day]}:  ${hours.label}');
        }
      }
    }

    final saturday = location.hours['sat'];
    if (saturday != null) lines.add('S:  ${saturday.label}');
    final sunday = location.hours['sun'];
    if (sunday != null && !sunday.closed) lines.add('D:  ${sunday.label}');

    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final schedule = _scheduleLines();

    return Card(
      child: InkWell(
        onTap: () => _showActions(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                location.name.toUpperCase(),
                style: const TextStyle(
                  color: CelfixColors.blue,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              if (location.address != null)
                _IconLine(
                  icon: Icons.location_on,
                  child: Text(
                    location.address!,
                    style: const TextStyle(
                        fontSize: 13.5, color: CelfixColors.ink),
                  ),
                ),
              if (schedule.isNotEmpty) ...[
                const SizedBox(height: 8),
                _IconLine(
                  icon: Icons.access_time,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final line in schedule)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: Text(
                            line,
                            style: const TextStyle(
                                fontSize: 13.5, color: CelfixColors.ink),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  final IconData icon;
  final Widget child;

  const _IconLine({required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: CelfixColors.blue),
        const SizedBox(width: 10),
        Expanded(child: child),
      ],
    );
  }
}
