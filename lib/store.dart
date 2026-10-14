import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Everything the app remembers, saved on the phone as one JSON document.
class Store extends ChangeNotifier {
  Store._();
  static final Store i = Store._();

  late SharedPreferences _prefs;
  Map<String, dynamic> d = {};

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs.getString('data');
    if (raw != null) {
      try {
        d = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      } catch (_) {
        d = {};
      }
    }
    d.putIfAbsent('profile', () => <String, dynamic>{});
    d.putIfAbsent('feeds', () => <dynamic>[]);
    d.putIfAbsent('nappies', () => <dynamic>[]);
    d.putIfAbsent('sleeps', () => <dynamic>[]);
    d.putIfAbsent('events', () => <dynamic>[
          {
            'id': 'shanti',
            'title': 'Ashlesha nakshatra shanti (Gandanta shanti)',
            'date': '2026-11-02',
            'time': '',
            'kind': 'Ceremony',
            'note': 'Ashlesha runs from about 5 AM on 2 Nov to 4 AM on 3 Nov. Backup dates: 29–30 Nov or 26–27 Dec 2026.'
          }
        ]);
    d.putIfAbsent('notes', () => <dynamic>[]);
    d.putIfAbsent('vax', () => <dynamic>[]);
    d.putIfAbsent('memories', () => <dynamic>[]);
    d.putIfAbsent('songFiles', () => <String, dynamic>{});
    d.putIfAbsent('shortlist', () => <dynamic>[]);
    d.putIfAbsent('growth', () => <dynamic>[]);
    d.putIfAbsent('mala', () => <String, dynamic>{});
    d.putIfAbsent('settings', () => <String, dynamic>{'interval': 150, 'alarm': true, 'sens': 18.0, 'wShh': true, 'wCry': true, 'wLull': true});
  }

  Future<void> save() async {
    await _prefs.setString('data', jsonEncode(d));
    notifyListeners();
  }

  // ---------- typed helpers ----------
  Map<String, dynamic> get profile => Map<String, dynamic>.from(d['profile'] as Map);
  Map<String, dynamic> get settings => Map<String, dynamic>.from(d['settings'] as Map);
  List<Map<String, dynamic>> list(String k) => (d[k] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  List<int> ints(String k) => (d[k] as List).map((e) => (e as num).toInt()).toList();

  bool get hasProfile => (profile['name'] ?? '').toString().isNotEmpty && (profile['birthDate'] ?? '').toString().isNotEmpty;
  DateTime? get birth {
    final s = profile['birthDate'];
    if (s == null || s.toString().isEmpty) return null;
    return DateTime.tryParse(s.toString());
  }

  String get babyName => (profile['name'] ?? 'Little One').toString().isEmpty ? 'Little One' : profile['name'].toString();

  Future<void> setProfile(Map<String, dynamic> p) async {
    d['profile'] = p;
    await save();
  }

  Future<void> setSetting(String k, dynamic v) async {
    final s = settings;
    s[k] = v;
    d['settings'] = s;
    await save();
  }

  Future<void> addTime(String k) async {
    final l = ints(k)..add(DateTime.now().millisecondsSinceEpoch);
    l.sort();
    d[k] = l.length > 400 ? l.sublist(l.length - 400) : l;
    await save();
  }

  Future<void> removeLast(String k) async {
    final l = ints(k);
    if (l.isEmpty) return;
    l.removeLast();
    d[k] = l;
    await save();
  }

  DateTime? last(String k) {
    final l = ints(k);
    return l.isEmpty ? null : DateTime.fromMillisecondsSinceEpoch(l.last);
  }

  int countToday(String k) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    return ints(k).where((t) => t >= start).length;
  }

  Future<void> addItem(String k, Map<String, dynamic> item) async {
    final l = (d[k] as List).toList()..add(item);
    d[k] = l;
    await save();
  }

  Future<void> removeItem(String k, String id) async {
    d[k] = (d[k] as List).where((e) => (e as Map)['id'] != id).toList();
    await save();
  }

  Future<void> toggleVax(String key, bool done) async {
    final l = (d['vax'] as List).map((e) => e.toString()).toSet();
    done ? l.add(key) : l.remove(key);
    d['vax'] = l.toList();
    await save();
  }

  bool vaxDone(String key) => (d['vax'] as List).contains(key);

  Future<void> setSongFile(String id, String? path) async {
    final m = Map<String, dynamic>.from(d['songFiles'] as Map);
    if (path == null) {
      m.remove(id);
    } else {
      m[id] = path;
    }
    d['songFiles'] = m;
    await save();
  }

  String? songFile(String id) => (d['songFiles'] as Map)[id] as String?;

  int mala(String id) => ((d['mala'] as Map)[id] as num?)?.toInt() ?? 0;
  Future<void> setMala(String id, int n) async {
    final m = Map<String, dynamic>.from(d['mala'] as Map);
    m[id] = n;
    d['mala'] = m;
    await save();
  }

  Future<void> toggleShortlist(String name) async {
    final l = (d['shortlist'] as List).map((e) => e.toString()).toList();
    l.contains(name) ? l.remove(name) : l.add(name);
    d['shortlist'] = l;
    await save();
  }

  bool inShortlist(String name) => (d['shortlist'] as List).contains(name);

  static String newId() => DateTime.now().microsecondsSinceEpoch.toString();

  /// Copies a picked file into the app's own folder so it stays after the gallery changes.
  static Future<String> keepFile(String srcPath, String folder) async {
    final dir = await getApplicationDocumentsDirectory();
    final out = Directory('${dir.path}/$folder');
    if (!out.existsSync()) out.createSync(recursive: true);
    final name = '${newId()}_${srcPath.split('/').last}';
    final f = await File(srcPath).copy('${out.path}/$name');
    return f.path;
  }

  /// One backup file with all text data (photos stay in the app folder).
  Future<String> exportBackup() async {
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/little_one_backup.json');
    await f.writeAsString(jsonEncode(d));
    return f.path;
  }

  Future<void> importBackup(String path) async {
    final raw = await File(path).readAsString();
    d = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    await load2();
  }

  Future<void> load2() async {
    await _prefs.setString('data', jsonEncode(d));
    await load();
    notifyListeners();
  }
}
