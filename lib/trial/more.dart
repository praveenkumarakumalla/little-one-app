import 'package:flutter/material.dart';

import '../store.dart';
import '../updater.dart';
import '../watch.dart';
import 'knowledge.dart';
import 'ui.dart';

/// Menu: cry listening, guides, schemes, language, baby details, updates, privacy.
class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Store.i,
      builder: (context, _) {
        final s = Store.i;
        Widget row(IconData icon, String title, String sub, VoidCallback onTap, {Color color = K.card}) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ClayBox(
                color: color,
                onTap: onTap,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Row(children: [
                  Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Icon(icon, color: K.indigo)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      if (sub.isNotEmpty) Text(sub, style: const TextStyle(fontSize: 12, color: K.muted)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right, color: K.muted),
                ]),
              ),
            );
        return ClayPage(title: tr('Menu', 'మెనూ'), children: [
          ClayBox(
            color: K.indigo,
            child: Row(children: [
              CircleAvatar(radius: 28, backgroundColor: K.pink, child: Text(s.babyName.isEmpty ? '?' : s.babyName.characters.first.toUpperCase(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: K.deep))),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.babyName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                  Text('${s.profile['birthDate'] ?? ''} · ${s.profile['birthTime'] ?? ''} · ${s.profile['place'] ?? ''}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          row(Icons.hearing, tr('Cry listening', 'ఏడుపు వినడం'), tr('Settings, history, what worked', 'సెట్టింగ్స్, చరిత్ర, ఏది పనిచేసింది'), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WatchPage()))),
          row(Icons.menu_book, tr('Guide books (PDF)', 'గైడ్ పుస్తకాలు (PDF)'), tr('For parents of girls and boys', 'పాప, బాబు తల్లిదండ్రుల కోసం'), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GuidesPage()))),
          row(Icons.savings, tr('Schemes & savings', 'పథకాలు, పొదుపు'), tr('Government help and savings plans', 'ప్రభుత్వ సహాయం, పొదుపు పథకాలు'), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SchemesPage()))),
          row(Icons.translate, tr('Language: English', 'భాష: తెలుగు'), tr('Tap to switch to Telugu', 'ఇంగ్లీష్‌కి మార్చడానికి నొక్కండి'), () => s.setSetting('tLang', K.te ? 'en' : 'te')),
          row(Icons.edit, tr('Change baby details', 'బిడ్డ వివరాలు మార్చండి'), tr('Name, birth date, time, place', 'పేరు, పుట్టిన తేదీ, సమయం, ఊరు'), () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (d) => AlertDialog(
                title: Text(tr('Set up again?', 'మళ్ళీ సెటప్ చేయాలా?')),
                content: Text(tr('You will enter the baby details again. Your logs and chat stay.', 'బిడ్డ వివరాలు మళ్ళీ ఇస్తారు. మీ నమోదులు, చాట్ అలాగే ఉంటాయి.')),
                actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tr('Cancel', 'వద్దు'))), FilledButton(onPressed: () => Navigator.pop(d, true), child: Text(tr('Yes', 'అవును')))],
              ),
            );
            if (ok == true) {
              await s.setSetting('tOnboarded', false);
              if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
            }
          }),
          row(Icons.system_update, tr('Check for app updates', 'యాప్ అప్‌డేట్ చూడండి'), '', () => Updater.check(context, manual: true)),
          row(Icons.verified_user, tr('Our privacy promise', 'మా గోప్యతా హామీ'), '', () {
            showDialog(
              context: context,
              builder: (d) => AlertDialog(
                title: Text(tr('Our privacy promise', 'మా గోప్యతా హామీ')),
                content: Text(tr(
                    '• Cry listening happens only on this phone. Sound is never uploaded.\n• Family chat is encrypted; only phones with your family code can read it.\n• We never sell your data.\n• Cry tips are guidance, not a diagnosis. Call your doctor when worried.',
                    '• ఏడుపు వినడం ఈ ఫోన్‌లోనే జరుగుతుంది. శబ్దం ఎక్కడికీ పంపబడదు.\n• ఫ్యామిలీ చాట్ ఎన్‌క్రిప్ట్ చేయబడింది; మీ కుటుంబ కోడ్ ఉన్న ఫోన్లు మాత్రమే చదవగలవు.\n• మీ డేటాను ఎప్పుడూ అమ్మము.\n• ఏడుపు చిట్కాలు మార్గదర్శనం మాత్రమే, రోగ నిర్ధారణ కాదు. ఆందోళనగా ఉంటే డాక్టర్‌కి ఫోన్ చేయండి.')),
                actions: [FilledButton(onPressed: () => Navigator.pop(d), child: const Text('OK'))],
              ),
            );
          }),
          const SizedBox(height: 8),
          Center(child: Text(tr('Little One · trial version', 'లిటిల్ వన్ · ట్రయల్ వెర్షన్'), style: const TextStyle(color: K.muted, fontSize: 12))),
        ]);
      },
    );
  }
}
