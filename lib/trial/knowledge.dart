import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../store.dart';
import 'ui.dart';

/// Guide books for parents of girls and boys (English + Telugu), readable here or as PDF.
class GuidesPage extends StatefulWidget {
  const GuidesPage({super.key});
  @override
  State<GuidesPage> createState() => _GuidesPageState();
}

class _GuidesPageState extends State<GuidesPage> {
  Map<String, dynamic>? data;
  late String gender;
  late String lang;

  @override
  void initState() {
    super.initState();
    gender = (Store.i.profile['gender'] ?? 'girl').toString();
    lang = K.te ? 'te' : 'en';
    rootBundle.loadString('assets/trial/guides.json').then((s) => setState(() => data = Map<String, dynamic>.from(jsonDecode(s) as Map)));
  }

  Future<String> _pdf() async {
    final name = '${gender}_$lang.pdf';
    final bytes = await rootBundle.load('assets/trial/guides/$name');
    final dir = await getTemporaryDirectory();
    final title = gender == 'girl' ? (lang == 'te' ? 'Maa_Papa_Guide' : 'Baby_Girl_Guide') : (lang == 'te' ? 'Maa_Babu_Guide' : 'Baby_Boy_Guide');
    final f = File('${dir.path}/$title${lang == 'te' ? '_Telugu' : ''}.pdf');
    await f.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    return f.path;
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    final chapters = d == null ? <Map>[] : (d['chapters'] as List).cast<Map>().where((c) => c['for'] == 'all' || c['for'] == gender).toList();
    final title = d == null ? '' : ((d['books'] as Map)[gender] as Map)[lang].toString();
    return ClayPage(title: tr('Guide books', 'గైడ్ పుస్తకాలు'), children: [
      Wrap(spacing: 10, runSpacing: 10, children: [
        Pill(tr('Baby girl', 'పాప'), on: gender == 'girl', onTap: () => setState(() => gender = 'girl')),
        Pill(tr('Baby boy', 'బాబు'), on: gender == 'boy', onTap: () => setState(() => gender = 'boy')),
        const SizedBox(width: 8),
        Pill('English', on: lang == 'en', onTap: () => setState(() => lang = 'en')),
        Pill('తెలుగు', on: lang == 'te', onTap: () => setState(() => lang = 'te')),
      ]),
      const SizedBox(height: 18),
      ClayBox(
        color: K.indigo,
        padding: const EdgeInsets.all(22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.menu_book, color: K.pink, size: 34),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
          Text(tr('${chapters.length} chapters · PDF book', '${chapters.length} అధ్యాయాలు · PDF పుస్తకం'), style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: K.pink, foregroundColor: K.deep),
                onPressed: () async => OpenFilex.open(await _pdf()),
                icon: const Icon(Icons.picture_as_pdf),
                label: Text(tr('Open PDF', 'PDF తెరవండి')),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filled(
              style: IconButton.styleFrom(backgroundColor: Colors.white24),
              onPressed: () async => Share.shareXFiles([XFile(await _pdf())], text: title),
              icon: const Icon(Icons.share, color: Colors.white),
            ),
          ]),
        ]),
      ),
      const SizedBox(height: 16),
      for (final c in chapters)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ClayBox(
            color: c['key'] == 'danger' ? const Color(0xFFFFE4E4) : K.card,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                shape: const Border(),
                title: Text((c['title'] as Map)[lang].toString(), style: TextStyle(fontWeight: FontWeight.w700, color: c['key'] == 'danger' ? K.bad : K.ink)),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                children: [
                  for (final it in (c[lang] as List))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if ((it as List)[0].toString().isNotEmpty) Text(it[0].toString(), style: const TextStyle(fontWeight: FontWeight.w700, color: K.indigo)),
                        Text(it[1].toString(), style: const TextStyle(height: 1.5)),
                      ]),
                    ),
                ],
              ),
            ),
          ),
        ),
      if (d != null) Text((d['note'] as Map)[lang].toString(), style: const TextStyle(fontSize: 11.5, color: K.muted)),
    ]);
  }
}

/// Government schemes and savings plans for the baby (information only).
class SchemesPage extends StatelessWidget {
  const SchemesPage({super.key});

  static Future<void> _open(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final girl = Store.i.profile['gender'] != 'boy';
    Widget item(IconData icon, String title, String body, String who, {String? link, Color color = K.card}) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ClayBox(
            color: color,
            onTap: link == null ? null : () => _open(link),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Icon(icon, color: K.indigo)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                  const SizedBox(height: 3),
                  Text(body, style: const TextStyle(height: 1.45)),
                  const SizedBox(height: 6),
                  Text(who, style: const TextStyle(fontSize: 12, color: K.indigo, fontWeight: FontWeight.w600)),
                ]),
              ),
              if (link != null) const Icon(Icons.open_in_new, size: 18, color: K.muted),
            ]),
          ),
        );
    return ClayPage(title: tr('Schemes & savings', 'పథకాలు, పొదుపు'), children: [
      SectionTitle(tr('Government schemes', 'ప్రభుత్వ పథకాలు')),
      item(Icons.volunteer_activism, tr('PM Matru Vandana Yojana', 'ప్రధాన మంత్రి మాతృ వందన యోజన'),
          tr('Rs 5,000 for the first child in two instalments, and Rs 6,000 more if the second child is a girl. Apply at your Anganwadi centre or through the ASHA worker with Aadhaar, bank account and MCP card.', 'మొదటి బిడ్డకు రెండు విడతల్లో రూ. 5,000, రెండో బిడ్డ ఆడపిల్ల అయితే మరో రూ. 6,000. ఆధార్, బ్యాంక్ ఖాతా, MCP కార్డుతో అంగన్‌వాడీ కేంద్రంలో లేదా ఆశా కార్యకర్త ద్వారా దరఖాస్తు చేయండి.'),
          tr('Mothers 19+', '19 ఏళ్ళు దాటిన తల్లులు'), link: 'https://pmmvy.wcd.gov.in/', color: K.pinkSoft),
      item(Icons.badge, tr('Birth certificate and Baal Aadhaar', 'జనన ధృవీకరణ పత్రం, బాల ఆధార్'), tr('Get the birth certificate early, then Baal Aadhaar for the baby. Most schemes ask for them.', 'ముందుగా జనన ధృవీకరణ పత్రం, తర్వాత బాల ఆధార్ తీసుకోండి. చాలా పథకాలు వీటిని అడుగుతాయి.'), tr('Every baby', 'ప్రతి బిడ్డకు'), link: 'https://uidai.gov.in/'),
      item(Icons.vaccines, tr('Free vaccines', 'ఉచిత టీకాలు'), tr('The Universal Immunisation Programme gives the main vaccines free at government centres. The Care tab reminds you of each date.', 'సార్వత్రిక టీకా కార్యక్రమం కింద ముఖ్యమైన టీకాలు ప్రభుత్వ కేంద్రాల్లో ఉచితం. కేర్ ట్యాబ్ ప్రతి తేదీని గుర్తు చేస్తుంది.'), tr('Every baby', 'ప్రతి బిడ్డకు')),
      item(Icons.child_friendly, tr('Anganwadi services', 'అంగన్‌వాడీ సేవలు'), tr('Nutrition support, growth checks and pre-school for mothers and children under 6.', 'తల్లులకు, 6 ఏళ్ళ లోపు పిల్లలకు పోషణ సహాయం, ఎదుగుదల పరీక్షలు, ప్రీ-స్కూల్.'), tr('Mothers and children under 6', 'తల్లులు, 6 ఏళ్ళ లోపు పిల్లలు')),
      item(Icons.map, tr('State schemes', 'రాష్ట్ర పథకాలు'), tr('Andhra Pradesh, Telangana and other states have their own schemes. We are checking them state by state.', 'ఆంధ్రప్రదేశ్, తెలంగాణ, ఇతర రాష్ట్రాలకు సొంత పథకాలు ఉన్నాయి. రాష్ట్రాల వారీగా పరిశీలిస్తున్నాం.'), tr('Coming soon', 'త్వరలో')),
      SectionTitle(tr('Savings for the baby', 'బిడ్డ కోసం పొదుపు')),
      if (girl)
        item(Icons.savings, tr('Sukanya Samriddhi Yojana', 'సుకన్య సమృద్ధి యోజన'), tr('8.2% a year for Oct–Dec 2026 (the rate is set every quarter). Opened at a post office or bank.', 'అక్టోబర్–డిసెంబర్ 2026కి సంవత్సరానికి 8.2% (ప్రతి త్రైమాసికం రేటు నిర్ణయిస్తారు). పోస్టాఫీసు లేదా బ్యాంకులో తెరవవచ్చు.'), tr('Girls under 10', '10 ఏళ్ళ లోపు ఆడపిల్లలు'), color: K.pinkSoft),
      item(Icons.account_balance, tr('Public Provident Fund (PPF)', 'పబ్లిక్ ప్రావిడెంట్ ఫండ్ (PPF)'), tr('7.1% a year for Oct–Dec 2026. A parent can open one for the child.', 'అక్టోబర్–డిసెంబర్ 2026కి సంవత్సరానికి 7.1%. తల్లిదండ్రులు బిడ్డ పేరున తెరవవచ్చు.'), tr('Any child', 'ఏ బిడ్డకైనా')),
      item(Icons.trending_up, tr('NPS Vatsalya', 'NPS వాత్సల్య'), tr('A long-term pension account for children. From Rs 250 a year; relatives can add gifts. Limited withdrawals for education or illness after 3 years.', 'పిల్లల కోసం దీర్ఘకాల పెన్షన్ ఖాతా. సంవత్సరానికి రూ. 250 నుంచి; బంధువులు కూడా జమ చేయవచ్చు. 3 ఏళ్ళ తర్వాత చదువు లేదా అనారోగ్యానికి పరిమితంగా తీసుకోవచ్చు.'), tr('Any child under 18, NRIs included', '18 ఏళ్ళ లోపు ఏ బిడ్డకైనా, NRIలు కూడా')),
      if (!girl) item(Icons.info_outline, tr('For girls', 'ఆడపిల్లల కోసం'), tr('Sukanya Samriddhi Yojana is only for girls under 10.', 'సుకన్య సమృద్ధి యోజన 10 ఏళ్ళ లోపు ఆడపిల్లలకు మాత్రమే.'), ''),
      const SizedBox(height: 6),
      Text(tr('Information only, not financial advice. Rates change every quarter; check at a post office or bank before investing.', 'ఇది సమాచారం మాత్రమే, ఆర్థిక సలహా కాదు. వడ్డీ రేట్లు ప్రతి త్రైమాసికం మారతాయి; పెట్టుబడి పెట్టే ముందు పోస్టాఫీసు లేదా బ్యాంకులో తెలుసుకోండి.'), style: const TextStyle(fontSize: 11.5, color: K.muted)),
    ]);
  }
}
