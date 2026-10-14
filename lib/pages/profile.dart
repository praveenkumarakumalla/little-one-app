import 'package:file_selector/file_selector.dart' show openFile, XTypeGroup;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data.dart';
import '../store.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final TextEditingController name, father, mother;
  DateTime? date;
  TimeOfDay? time;
  String place = 'Nellore';

  @override
  void initState() {
    super.initState();
    final p = Store.i.profile;
    name = TextEditingController(text: (p['name'] ?? '').toString());
    father = TextEditingController(text: (p['father'] ?? '').toString());
    mother = TextEditingController(text: (p['mother'] ?? '').toString());
    date = DateTime.tryParse((p['birthDate'] ?? '').toString());
    final t = (p['birthTime'] ?? '').toString().split(':');
    if (t.length == 2) time = TimeOfDay(hour: int.tryParse(t[0]) ?? 0, minute: int.tryParse(t[1]) ?? 0);
    if (places.containsKey(p['place'])) place = p['place'].toString();
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Her details')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: "Baby's name", border: OutlineInputBorder())),
        const SizedBox(height: 12),
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Theme.of(context).colorScheme.outline)),
          title: Text(date == null ? 'Date of birth' : 'Born ${dmy(date!)}'),
          trailing: const Icon(Icons.calendar_month),
          onTap: () async {
            final d = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime(2035), initialDate: date ?? DateTime.now());
            if (d != null) setState(() => date = d);
          },
        ),
        const SizedBox(height: 12),
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Theme.of(context).colorScheme.outline)),
          title: Text(time == null ? 'Time of birth' : 'Time ${time!.format(context)}'),
          trailing: const Icon(Icons.schedule),
          onTap: () async {
            final t = await showTimePicker(context: context, initialTime: time ?? const TimeOfDay(hour: 18, minute: 18));
            if (t != null) setState(() => time = t);
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: place,
          decoration: const InputDecoration(labelText: 'Place of birth', border: OutlineInputBorder()),
          items: places.keys.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
          onChanged: (v) => setState(() => place = v ?? 'Nellore'),
        ),
        const SizedBox(height: 12),
        TextField(controller: father, decoration: const InputDecoration(labelText: 'Father (optional)', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: mother, decoration: const InputDecoration(labelText: 'Mother (optional)', border: OutlineInputBorder())),
        const SizedBox(height: 16),
        FilledButton(
          style: FilledButton.styleFrom(padding: const EdgeInsets.all(16)),
          onPressed: () async {
            if (name.text.trim().isEmpty || date == null) {
              _snack('Add her name and date of birth.');
              return;
            }
            await Store.i.setProfile({
              'name': name.text.trim(),
              'birthDate': ymd(date!),
              'birthTime': time == null ? '' : '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}',
              'place': place,
              'father': father.text.trim(),
              'mother': mother.text.trim(),
            });
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
        const Divider(height: 40),
        const Text('Backup', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const Text('Save feeds, notes, vaccines and events to Google Drive or WhatsApp, so nothing is lost if the phone changes. Photos stay in the phone gallery.'),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.backup),
              label: const Text('Save backup'),
              onPressed: () async {
                final path = await Store.i.exportBackup();
                await Share.shareXFiles([XFile(path)], text: 'Little One diary backup');
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.restore),
              label: const Text('Restore'),
              onPressed: () async {
                final f = await openFile(acceptedTypeGroups: [const XTypeGroup(label: 'Backup', extensions: ['json'])]);
                if (f == null) return;
                try {
                  await Store.i.importBackup(f.path);
                  _snack('Backup restored');
                } catch (_) {
                  _snack('That file is not a Little One backup.');
                }
              },
            ),
          ),
        ]),
      ]),
    );
  }
}
