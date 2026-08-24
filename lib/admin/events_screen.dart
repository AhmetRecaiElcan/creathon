import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/util/time_format.dart';
import '../domain/event_session.dart';
import '../domain/taxonomy.dart';
import 'event_admin_repository.dart';

/// The programme, from the organiser's side.
///
/// One session posted here lands on all four portfolios' home feeds and on the
/// investor's ETKİNLİKLER tab at once — the app already reads the whole
/// collection for everyone, so there is nothing to target and nothing to
/// duplicate.
class EventsAdminScreen extends ConsumerWidget {
  const EventsAdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(adminEventsProvider);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const _AddEventCard(),
        const SizedBox(height: 24),
        Text(
          'PROGRAMDAKİ ETKİNLİKLER',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            letterSpacing: 1.2,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 12),
        switch (events) {
          AsyncData(value: final rows) when rows.isEmpty => const _Message(
            'Programda henüz etkinlik yok. Yukarıdan ekleyince '
            'her müşteri türünün ana sayfasına düşer.',
          ),
          AsyncData(value: final rows) => Column(
            children: [for (final event in rows) _EventRow(event: event)],
          ),
          AsyncError(error: final error) => _Message('Okunamadı: $error'),
          _ => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
        },
      ],
    );
  }
}

class _AddEventCard extends ConsumerStatefulWidget {
  const _AddEventCard();

  @override
  ConsumerState<_AddEventCard> createState() => _AddEventCardState();
}

class _AddEventCardState extends ConsumerState<_AddEventCard> {
  final _title = TextEditingController();
  final _venue = TextEditingController();
  final _speaker = TextEditingController();
  final _org = TextEditingController();

  SessionKind _kind = SessionKind.panel;
  DateTime? _day;
  TimeOfDay? _from;
  TimeOfDay? _to;
  final _sectors = <String>{};

  bool _busy = false;
  String? _error;
  String? _done;

  @override
  void dispose() {
    _title.dispose();
    _venue.dispose();
    _speaker.dispose();
    _org.dispose();
    super.dispose();
  }

  /// Combines the picked day and time into an instant.
  ///
  /// Kept as three separate pickers because that is how the organiser thinks
  /// about it — "27 Ağustos, 14:00 to 15:30" — and because a single datetime
  /// field would make the end time's date a thing to get wrong.
  DateTime? _at(TimeOfDay? time) {
    final day = _day;
    if (day == null || time == null) return null;
    return DateTime(day.year, day.month, day.day, time.hour, time.minute);
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _day ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => _day = picked);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          (isStart ? _from : _to) ?? const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _from = picked;
        // The end almost always follows the start on the same afternoon, and
        // an hour is the commonest session — so offer it rather than make the
        // organiser open a second picker for the usual case.
        _to ??= TimeOfDay(hour: (picked.hour + 1) % 24, minute: picked.minute);
      } else {
        _to = picked;
      }
    });
  }

  Future<void> _submit() async {
    final start = _at(_from);
    final end = _at(_to);
    if (_day == null) {
      setState(() => _error = 'Tarih seç.');
      return;
    }
    if (start == null || end == null) {
      setState(() => _error = 'Başlangıç ve bitiş saatini seç.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _done = null;
    });
    try {
      await ref.read(eventAdminRepositoryProvider).add(
        title: _title.text,
        venue: _venue.text,
        start: start,
        end: end,
        kind: _kind,
        speaker: _speaker.text,
        org: _org.text,
        sectors: _sectors.toList(),
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _done =
            '${_title.text.trim()} programa eklendi — '
            '${formatDay(start)} ${formatHm(start)}–${formatHm(end)}.';
        _title.clear();
        _venue.clear();
        _speaker.clear();
        _org.clear();
        _sectors.clear();
        _from = null;
        _to = null;
      });
    } on EventFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = failure.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Kaydedilemedi: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final start = _at(_from);
    final end = _at(_to);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Yeni etkinlik oluştur',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Eklenen etkinlik dört müşteri türünün ana sayfasında ve '
              'yatırımcının ETKİNLİKLER sekmesinde görünür.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Etkinlik adı',
                hintText: 'Savunma Teknolojilerinde Otonomi',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _venue,
              decoration: const InputDecoration(
                labelText: 'Yer',
                hintText: 'Ana Sahne / Salon B / A Holü',
              ),
            ),
            const SizedBox(height: 16),

            // Day and hours. Shown as three buttons that state their own value,
            // so the form can be read back at a glance before it is submitted.
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _PickerButton(
                  icon: Icons.calendar_today_rounded,
                  label: _day == null ? 'Tarih seç' : formatDay(_day!),
                  onPressed: _pickDay,
                ),
                _PickerButton(
                  icon: Icons.schedule_rounded,
                  label: start == null
                      ? 'Başlangıç'
                      : 'Başlangıç  ${formatHm(start)}',
                  onPressed: () => _pickTime(isStart: true),
                ),
                _PickerButton(
                  icon: Icons.schedule_rounded,
                  label: end == null ? 'Bitiş' : 'Bitiş  ${formatHm(end)}',
                  onPressed: () => _pickTime(isStart: false),
                ),
              ],
            ),

            const SizedBox(height: 20),
            _Label('TÜR'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final kind in SessionKind.values)
                  ChoiceChip(
                    label: Text(kind.label),
                    avatar: Icon(kind.icon, size: 18),
                    selected: _kind == kind,
                    onSelected: (_) => setState(() => _kind = kind),
                  ),
              ],
            ),

            const SizedBox(height: 20),
            const _Label('KONUŞMACI (OPSİYONEL)'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _speaker,
                    decoration: const InputDecoration(labelText: 'Kişi'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _org,
                    decoration: const InputDecoration(labelText: 'Kurum'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const _Label('SEKTÖRLER (OPSİYONEL)'),
            const SizedBox(height: 4),
            Text(
              'Seçilen sektörler, o alanla ilgilenen kullanıcıların ana '
              'sayfasında etkinliği öne çıkarır.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final sector in Taxonomy.sectors)
                  FilterChip(
                    label: Text(sector),
                    selected: _sectors.contains(sector),
                    onSelected: (on) => setState(() {
                      on ? _sectors.add(sector) : _sectors.remove(sector);
                    }),
                  ),
              ],
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (_done != null) ...[
              const SizedBox(height: 16),
              Text(_done!, style: const TextStyle(color: Color(0xFF2FD98A))),
            ],

            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Programa ekle'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventRow extends ConsumerWidget {
  const _EventRow({required this.event});

  final EventSession event;

  Future<void> _confirmRemove(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Etkinliği kaldır'),
        content: Text(
          '"${event.title}" programdan silinecek ve tüm kullanıcıların ana '
          'sayfasından kalkacak. Ajandasına eklemiş olanların listesinden de '
          'kendiliğinden düşer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kaldır'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(eventAdminRepositoryProvider).remove(event.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(event.kind.icon, color: Colors.white70),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                Text(
                  [
                    '${formatDay(event.start)}  ${event.timeLabel}',
                    if (event.venue.isNotEmpty) event.venue,
                    if (event.speaker.isNotEmpty) event.speaker,
                  ].join('  ·  '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (event.sectors.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      event.sectors.join(', '),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white38,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Programdan kaldır',
            onPressed: () => _confirmRemove(context, ref),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    ),
  );
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 18),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      letterSpacing: 1.1,
      color: Colors.white54,
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    ),
  );
}
