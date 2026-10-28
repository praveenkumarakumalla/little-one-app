import 'dart:io';
import 'dart:math' as math;

import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'store.dart';
import 'voice.dart';

/// "Talking baby": the app itself speaks in a cute baby voice —
/// every hour 8 AM–8 PM it asks about the family, at 12 PM it wants biryani or pizza (said twice),
/// at 8 AM it says good morning, and at 8 PM good night with "Jai Shree Ram". Works even when the app is closed
/// (the sentences are saved as voice files on the phone and played by the alarm service).
class Talk {
  static const base = 1000; // alarm ids 1000…1099
  static const version = 4; // bump when the words change, to re-make the voice files

  /// key: [Telugu, Devanagari (for Hindi voice), Latin (for English voice), notification title]
  static const lines = <String, List<String>>{
    'amma': ['హలో అమ్మా! నేను నీ చిన్ని బేబీని. ఏం చేస్తున్నావ్?', 'हलो अम्मा! नेनु नी चिन्नि बेबीनि. एम चेस्तुन्नाव?', 'Hello Amma! Nenu nee chinni baby ni. Em chestunnav?', '👶 హలో అమ్మా! ఏం చేస్తున్నావ్?'],
    'nanna': ['హలో! నాన్న ఏం చేస్తున్నాడు?', 'हलो! नान्ना एम चेस्तुन्नाडु?', 'Hello! Nanna em chestunnadu?', '👶 నాన్న ఏం చేస్తున్నాడు?'],
    'ammamma': ['అమ్మమ్మ ఏం చేస్తోంది?', 'अम्मम्मा एम चेस्तोंदि?', 'Ammamma em chestondi?', '👶 అమ్మమ్మ ఏం చేస్తోంది?'],
    'tatayya': ['తాతయ్య ఏం చేస్తున్నాడు?', 'तातय्या एम चेस्तुन्नाडु?', 'Tatayya em chestunnadu?', '👶 తాతయ్య ఏం చేస్తున్నాడు?'],
    'biryani': ['అమ్మా, నాకు బిర్యానీ కావాలి! ... అమ్మా, నాకు బిర్యానీ కావాలి!', 'अम्मा, नाकु बिर्यानी कावालि! ... अम्मा, नाकु बिर्यानी कावालि!', 'Amma, naku biryani kavali! ... Amma, naku biryani kavali!', '🍗 అమ్మా, నాకు బిర్యానీ కావాలి!'],
    'pizza': ['అమ్మా, నాకు పిజ్జా కావాలి! ... అమ్మా, నాకు పిజ్జా కావాలి!', 'अम्मा, नाकु पिज़्ज़ा कावालि! ... अम्मा, नाकु पिज़्ज़ा कावालि!', 'Amma, naku pizza kavali! ... Amma, naku pizza kavali!', '🍕 అమ్మా, నాకు పిజ్జా కావాలి!'],
    'gm': ['గుడ్ మార్నింగ్ అమ్మా! లేచావా?', 'गुड मॉर्निंग अम्मा! लेचावा?', 'Good morning Amma! Lechava?', '☀️ గుడ్ మార్నింగ్ అమ్మా! లేచావా?'],
    'gn': ['గుడ్ నైట్ అమ్మా! నాకు జై శ్రీ రామ్ చెప్పి బజ్జో. జై శ్రీ రామ్!', 'गुड नाइट अम्मा! नाकु जय श्री राम चेप्पि बज्जो. जय श्री राम!', 'Good night Amma! Naku Jai Shree Ram cheppi bajjo. Jai Shree Ram!', '🌙 గుడ్ నైట్ అమ్మా! జై శ్రీ రామ్ చెప్పి బజ్జో'],
    'f_boss': ['నాన్నా! ఆఫీస్‌లో బాస్ తిడుతున్నాడా? నాకు చెప్పు, నేను చూసుకుంటా!', 'Nanna! Office lo boss tidutunnada? Naku cheppu, nenu chusukunta!', 'Nanna! Office lo boss tidutunnada? Naku cheppu, nenu chusukunta!', '😤 నాన్నా, బాస్ తిడుతున్నాడా?'],
    'f_diaper': ['అమ్మా, ఒక చిన్న విషయం. డైపర్ చెక్ చెయ్యి. నేను ఏమీ చెయ్యలేదు, ఊరికే అడుగుతున్నా!', 'Amma, oka chinna vishayam. Diaper check cheyyi. Nenu emi cheyyaledu, ooriki adugutunna!', 'Amma, oka chinna vishayam. Diaper check cheyyi. Nenu emi cheyyaledu, ooriki adugutunna!', '🙈 అమ్మా, డైపర్ చెక్ చెయ్యి'],
    'f_serial': ['అమ్మమ్మా! సీరియల్ ఆపి నన్ను చూడు! నేను సీరియల్ కంటే క్యూట్!', 'Ammamma! Serial aapi nannu choodu! Nenu serial kante cute!', 'Ammamma! Serial aapi nannu choodu! Nenu serial kante cute!', '📺 అమ్మమ్మా, సీరియల్ ఆపు!'],
    'f_paper': ['తాతయ్యా! పేపర్‌లో నా గురించి ఏమైనా వచ్చిందా? ఈ ఇంటి సెలబ్రిటీ నేనే కదా!', 'Tatayya! Paper lo naa gurinchi emaina vachinda? Ee inti celebrity nene kada!', 'Tatayya! Paper lo naa gurinchi emaina vachinda? Ee inti celebrity nene kada!', '😎 తాతయ్యా, పేపర్‌లో నేనున్నానా?'],
    'f_secret': ['అమ్మా, ఒక సీక్రెట్ చెప్పనా? రాత్రి రెండు గంటలకు నేను లేచేది నిన్ను మిస్ అవుతున్నాననే!', 'Amma, oka secret cheppana? Ratri rendu gantalaku nenu lechedi ninnu miss avutunnanane!', 'Amma, oka secret cheppana? Ratri rendu gantalaku nenu lechedi ninnu miss avutunnanane!', '🤭 అమ్మా, ఒక సీక్రెట్!'],
    'f_phone': ['నాన్నా! ఫోన్ కాస్త పక్కన పెట్టు, నన్ను చూడు! నేను రీల్స్ కంటే బాగుంటా!', 'Nanna! Phone kasta pakkana pettu, nannu choodu! Nenu reels kante baguntaa!', 'Nanna! Phone kasta pakkana pettu, nannu choodu! Nenu reels kante baguntaa!', '📱 నాన్నా, ఫోన్ పక్కన పెట్టు!'],
    'f_looks': ['అమ్మా, నేను ఎవరి పోలిక? నీదా, నాన్నదా? నాకు తెలుసులే, నా అందం నాదే!', 'Amma, nenu evari polika? Needa, nannada? Naku telusule, naa andam naade!', 'Amma, nenu evari polika? Needa, nannada? Naku telusule, naa andam naade!', '😌 నేను ఎవరి పోలిక?'],
    'f_review': ['అమ్మా, ఈరోజు పాలు టేస్ట్ సూపర్! ఫైవ్ స్టార్ రేటింగ్!', 'Amma, eeroju paalu taste super! Five star rating!', 'Amma, eeroju paalu taste super! Five star rating!', '⭐ పాలకు ఫైవ్ స్టార్!'],
    'f_gym': ['నాన్నా, నువ్వు జిమ్‌కి వెళ్ళక్కర్లేదు. నన్ను ఎత్తుకుని తిప్పు, అదే వర్కౌట్!', 'Nanna, nuvvu gym ki vellakkarledu. Nannu ettukuni tippu, ade workout!', 'Nanna, nuvvu gym ki vellakkarledu. Nannu ettukuni tippu, ade workout!', '💪 నాన్నా, నేనే నీ జిమ్!'],
    'f_song': ['అమ్మా, నాకు ఒక పాట పాడు. బాగోలేకపోయినా పర్వాలేదు, నేను చప్పట్లు కొడతా!', 'Amma, naku oka paata paadu. Bagolekapoyina parvaledu, nenu chappatlu kodata!', 'Amma, naku oka paata paadu. Bagolekapoyina parvaledu, nenu chappatlu kodata!', '🎵 అమ్మా, ఒక పాట పాడు!'],
    'f_madam': ['అందరికీ ఒక అప్‌డేట్! నేను ఈరోజు కొంచెం పెద్దయ్యా. ఇప్పటినుంచి నన్ను మేడమ్ అని పిలవండి!', 'Andariki oka update! Nenu eeroju konchem peddayya. Ippatinunchi nannu madam ani pilavandi!', 'Andariki oka update! Nenu eeroju konchem peddayya. Ippatinunchi nannu madam ani pilavandi!', '👑 నన్ను మేడమ్ అని పిలవండి!'],
    'f_fan': ['ఈ ఇంట్లో ఫ్యాన్ నా బెస్ట్ ఫ్రెండ్. నేను దాన్ని చూస్తా, అది నన్ను చూసి తిరుగుతుంది!', 'Ee intlo fan naa best friend. Nenu danni chusta, adi nannu chusi tirugutundi!', 'Ee intlo fan naa best friend. Nenu danni chusta, adi nannu chusi tirugutundi!', '🌀 ఫ్యాన్ నా బెస్ట్ ఫ్రెండ్!'],
    'f_anna': ['అన్నయ్యా! ఏం చేస్తున్నావ్? స్కూల్ నుంచి వచ్చావా? నాకు ఏం తెచ్చావ్?', 'Annayya! Em chestunnav? School nunchi vachava? Naku em techav?', 'Annayya! Em chestunnav? School nunchi vachava? Naku em techav?', '🧒 అన్నయ్యా, నాకు ఏం తెచ్చావ్?'],
    'f_anna_toys': ['అన్నయ్యా, నీ బొమ్మలన్నీ ఇప్పుడు నావే! షేర్ చేయడం నేర్చుకో!', 'Annayya, nee bommalanni ippudu naave! Share cheyadam nerchuko!', 'Annayya, nee bommalanni ippudu naave! Share cheyadam nerchuko!', '🧸 అన్నయ్యా, నీ బొమ్మలు నావే!'],
    'f_anna_boss': ['అన్నయ్యా, ఈ ఇంట్లో ఇప్పుడు బాస్ ఎవరో తెలుసా? నేనే! అందరూ నా మాటే వింటారు!', 'Annayya, ee intlo ippudu boss evaro telusa? Nene! Andaru naa maate vintaru!', 'Annayya, ee intlo ippudu boss evaro telusa? Nene! Andaru naa maate vintaru!', '👑 అన్నయ్యా, ఇప్పుడు బాస్ నేనే!'],
    'f_anna_sleep': ['అమ్మా! అన్నయ్య నేను నిద్రపోతుంటే డిస్టర్బ్ చేస్తున్నాడు! కాస్త చెప్పు!', 'Amma! Annayya nenu nidrapotunte disturb chestunnadu! Kasta cheppu!', 'Amma! Annayya nenu nidrapotunte disturb chestunnadu! Kasta cheppu!', '😠 అమ్మా, అన్నయ్య డిస్టర్బ్ చేస్తున్నాడు!'],
    'f_anna_cheeks': ['అమ్మా! అన్నయ్య నా బుగ్గలు గిల్లుతున్నాడు! నేను క్యూట్‌గా ఉంటే అది నా తప్పా?', 'Amma! Annayya naa buggalu gillutunnadu! Nenu cute ga unte adi naa tappa?', 'Amma! Annayya naa buggalu gillutunnadu! Nenu cute ga unte adi naa tappa?', '😤 అన్నయ్య బుగ్గలు గిల్లుతున్నాడు!'],
    'f_anna_bottle': ['అమ్మా! అన్నయ్య నా పాల సీసా దాచేశాడు! నేను ఏడుస్తా, చూడు!', 'Amma! Annayya naa paala seesa daachesadu! Nenu edusta, choodu!', 'Amma! Annayya naa paala seesa daachesadu! Nenu edusta, choodu!', '🍼 అన్నయ్య నా పాల సీసా దాచాడు!'],
    'ram': ['అమ్మా, నాకు జై శ్రీ రామ్ చెప్పు! జై శ్రీ రామ్!', 'अम्मा, नाकु जय श्री राम चेप्पु! जय श्री राम!', 'Amma, naku Jai Shree Ram cheppu! Jai Shree Ram!', '🙏 అమ్మా, నాకు జై శ్రీ రామ్ చెప్పు!'],
  };

  /// Quick replies shown in the app when it asks: [button, what the baby says back]
  static const replies = <String, List<List<String>>>{
    'ask': [
      ['💼 పని చేస్తున్నా', 'సరే! త్వరగా వచ్చేయ్!', 'r_work'],
      ['🍳 వంట చేస్తున్నా', 'యమ్మీ! నాకు కూడా!', 'r_cook'],
      ['😴 రెస్ట్ తీసుకుంటున్నా', 'సరే, బజ్జో!', 'r_rest'],
      ['🥰 నీ గురించే ఆలోచిస్తున్నా', 'నేను కూడా! ఐ లవ్ యూ!', 'r_love'],
    ],
    'food': [
      ['🍗 సరే, తెస్తా!', 'యే! థాంక్యూ అమ్మా!', 'r_food_yes'],
      ['🍼 ముందు పాలు తాగు', 'సరే అమ్మా… పాలే నాకు ఇష్టం!', 'r_food_milk'],
    ],
    'gm': [
      ['☀️ లేచా!', 'యే! గుడ్ మార్నింగ్ అమ్మా! ఐ లవ్ యూ!', 'r_gm'],
      ['😴 ఇంకా నిద్ర', 'సరే, ఇంకొంచెం బజ్జో అమ్మా!', 'r_rest'],
    ],
    'f_boss': [
      ['😂 చెప్పేస్తా', 'సరే! రేపు నేను వచ్చి గట్టిగా ఏడుస్తా. బాస్ పారిపోతాడు!', 'r_f_boss_1'],
      ['🥰 అంతా ఓకే', 'గుడ్! త్వరగా ఇంటికి రా, నాకు ఆడుకోవాలి!', 'r_f_boss_2'],
    ],
    'f_diaper': [
      ['🧷 చెక్ చేస్తా', 'హి హి, సారీ అమ్మా! నువ్వే బెస్ట్!', 'r_f_diaper_1'],
      ['😤 మళ్ళీనా?', 'ఏం చేయను అమ్మా, పాలు ఎక్కువ తాగా కదా!', 'r_f_diaper_2'],
    ],
    'f_serial': [
      ['😂 నువ్వే క్యూట్', 'కదా! ఇప్పుడు నాకు ఒక ముద్దు ఇవ్వు!', 'r_f_serial_1'],
      ['📺 ఒక్క ఎపిసోడ్', 'సరే, కానీ యాడ్స్ వచ్చినప్పుడు నాతో ఆడుకోవాలి!', 'r_f_serial_2'],
    ],
    'f_paper': [
      ['📰 ఫ్రంట్ పేజీలో!', 'హహ! ఆటోగ్రాఫ్ కావాలంటే లైన్‌లో రండి!', 'r_f_paper_1'],
      ['😂 ఇంకా లేదు', 'పర్వాలేదు తాతయ్యా, త్వరలోనే వస్తుంది!', 'r_f_paper_2'],
    ],
    'f_secret': [
      ['🥹 అయ్యో బంగారం', 'అందుకే ఈరోజు రాత్రి కూడా లేస్తా! హి హి!', 'r_f_secret_1'],
      ['😴 ఈరోజు బజ్జో', 'ప్రామిస్ చేయను, కానీ ట్రై చేస్తా!', 'r_f_secret_2'],
    ],
    'f_phone': [
      ['😂 నిజమే', 'అయితే నా వీడియో తీసి అందరికీ పంపు!', 'r_f_phone_1'],
      ['📱 ఒక్క నిమిషం', 'ఒక్క నిమిషం అంటే నేను లెక్కపెడుతున్నా! ఒకటి, రెండు, మూడు!', 'r_f_phone_2'],
    ],
    'f_looks': [
      ['👩 నా పోలికే', 'అందుకే నేను ఇంత అందంగా ఉన్నా!', 'r_f_looks_1'],
      ['👨 నాన్న పోలిక', 'హ్మ్, అయితే నవ్వు మాత్రం అమ్మదే!', 'r_f_looks_2'],
    ],
    'f_review': [
      ['😂 థాంక్యూ', 'నెక్స్ట్ ఆర్డర్ ఇంకో గంటలో. రెడీగా ఉండు!', 'r_f_review_1'],
      ['🍼 ఇంకా కావాలా?', 'అబ్బో! నువ్వు బెస్ట్ అమ్మవి!', 'r_f_review_2'],
    ],
    'f_gym': [
      ['💪 సరే, రా', 'యే! ఇంకోసారి, ఇంకోసారి!', 'r_f_gym_1'],
      ['😅 అలసిపోయా', 'సరే, నా పక్కన పడుకో. ఇద్దరం బజ్జుందాం!', 'r_f_gym_2'],
    ],
    'f_song': [
      ['🎵 పాడుతా', 'సూపర్! నువ్వే నా ఫేవరెట్ సింగర్!', 'r_f_song_1'],
      ['😂 నువ్వే పాడు', 'ఊ ఆ, ఊ ఆ! ఎలా ఉంది నా పాట?', 'r_f_song_2'],
    ],
    'f_madam': [
      ['👑 సరే మేడమ్', 'హహ! మేడమ్‌కి ఇప్పుడు పాలు కావాలి!', 'r_f_madam_1'],
      ['🥰 నువ్వు చిన్నారివే', 'సరే సరే, ఎప్పటికీ మీ చిన్నారినే!', 'r_f_madam_2'],
    ],
    'f_fan': [
      ['😂 నేను కాదా?', 'నువ్వు బెస్ట్ బెస్ట్ ఫ్రెండ్ అమ్మా!', 'r_f_fan_1'],
      ['🌀 హాయ్ చెప్పు', 'హాయ్ ఫ్యాన్! తిరుగుతూనే ఉండు!', 'r_f_fan_2'],
    ],
    'f_anna': [
      ['🍫 చాక్లెట్ తెచ్చా', 'యే! కానీ నాకు పళ్ళు లేవు, నువ్వే తిను, నేను చూస్తా!', 'r_f_anna_1'],
      ['🎒 హోంవర్క్ ఉంది', 'అయ్యో! సరే, త్వరగా చేసి నాతో ఆడుకో!', 'r_f_anna_2'],
    ],
    'f_anna_toys': [
      ['😂 సరే చెల్లి', 'థాంక్యూ అన్నయ్యా! నువ్వే బెస్ట్ అన్నయ్య!', 'r_f_anna_toys_1'],
      ['😤 అస్సలు ఇవ్వను', 'అయితే అమ్మకి చెప్తా! అమ్మా!', 'r_f_anna_toys_2'],
    ],
    'f_anna_boss': [
      ['😂 నిజమే', 'అయితే బాస్ ఆర్డర్: నన్ను నవ్వించు!', 'r_f_anna_boss_1'],
      ['🙅 నేనే బాస్', 'సరే, నువ్వు పెద్ద బాస్, నేను చిన్న బాస్!', 'r_f_anna_boss_2'],
    ],
    'f_anna_sleep': [
      ['😠 అన్నయ్యా, ఆపు!', 'హమ్మయ్య! థాంక్యూ అమ్మా. ఇప్పుడు హాయిగా బజ్జుంటా!', 'r_f_anna_sleep_1'],
      ['😂 నిన్ను ఆడించాలని', 'సరే సరే, ఒక్క ఐదు నిమిషాలు ఆడుకుంటా. తర్వాత నిద్ర!', 'r_f_anna_sleep_2'],
    ],
    'f_anna_cheeks': [
      ['😂 నువ్వు క్యూట్ కదా', 'కదా! అయితే గిల్లకుండా ముద్దు పెట్టమను!', 'r_f_anna_cheeks_1'],
      ['😠 అన్నయ్యా, వద్దు!', 'థాంక్యూ అమ్మా! అన్నయ్యా, సారీ చెప్పు!', 'r_f_anna_cheeks_2'],
    ],
    'f_anna_bottle': [
      ['🍼 ఇదిగో సీసా', 'యే! దొరికింది! అన్నయ్యా, ఈసారి నీకు ఇవ్వను!', 'r_f_anna_bottle_1'],
      ['😂 ఏడవకు బంగారం', 'సరే ఏడవను, కానీ అన్నయ్యకి ఒక చిన్న పనిష్మెంట్ ఇవ్వు!', 'r_f_anna_bottle_2'],
    ],
    'ram': [
      ['🙏 జై శ్రీ రామ్!', 'జై శ్రీ రామ్! థాంక్యూ అమ్మా. గుడ్ నైట్!', 'r_ram'],
    ],
  };

  static bool get enabled => Store.i.settings['talk'] != false;

  static Future<Directory> _dir() async {
    final d = Directory('${(await getApplicationDocumentsDirectory()).path}/talk');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  static Future<String> _path(String key) async => '${(await _dir()).path}/$key.wav';

  /// Make the voice files (once, or when the words change). Needs the phone's text-to-speech.
  static Future<void> prepare({bool force = false}) async {
    final ver = (Store.i.settings['talkVer'] as num?)?.toInt() ?? 0;
    final lang = Voice.i.lang ?? '';
    final redo = force || ver != version || Store.i.settings['talkLang'] != lang;
    for (final e in lines.entries) {
      if (Voice.i.hasClip(e.key)) continue;
      final p = await _path(e.key);
      final f = File(p);
      if (!redo && f.existsSync() && f.lengthSync() > 2000) continue;
      await Voice.i.synthToFile(e.value[0], p, dev: e.value[1], lat: e.value[2], pitch: 1.85);
    }
    await Store.i.setSetting('talkVer', version);
    await Store.i.setSetting('talkLang', lang);
  }

  static Future<void> _cancelAll() async {
    for (var i = 0; i < 100; i++) {
      try {
        await Alarm.stop(base + i);
      } catch (_) {}
    }
  }

  static bool isTalk(int id) => id >= base && id < base + 100;

  static String? keyFor(int id) => (Map<String, dynamic>.from((Store.i.settings['talkPlan'] ?? {}) as Map))['$id']?.toString();

  /// Plan the next 3 days. Called when the app opens and after each ring.
  static Future<void> reschedule() async {
    try {
      await _cancelAll();
      if (!enabled) return;
      await prepare();
      final now = DateTime.now();
      final r = math.Random();
      final plan = <String, String>{};
      var id = base;
      // funny conversation lines, shuffled so each day sounds different
      // fixed times chosen by the family; the other hours get a shuffled funny line
      const fixed = {14: 'f_review', 17: 'f_secret', 18: 'f_anna_sleep', 19: 'f_serial', 20: 'f_phone'};
      const favourites = ['f_diaper', 'f_song', 'f_madam'];
      const others = ['f_boss', 'f_paper', 'f_looks', 'f_gym', 'f_fan', 'f_anna', 'f_anna_toys', 'f_anna_boss', 'f_anna_cheeks', 'f_anna_bottle'];
      final rest = <String>[];
      for (var day = 0; day < 3; day++) {
        final d0 = DateTime(now.year, now.month, now.day + day);
        final slots = <MapEntry<DateTime, String>>[];
        // 9, 10, 11, 13, 15, 16: the 3 favourites every day + 3 others, in a new order each day
        if (rest.length < 3) rest.addAll(others.toList()..shuffle(r));
        final today = [...favourites, rest.removeLast(), rest.removeLast(), rest.removeLast()]..shuffle(r);
        for (var h = 8; h <= 20; h++) {
          String key;
          if (h == 8) {
            key = 'gm';
          } else if (h == 12) {
            key = r.nextBool() ? 'biryani' : 'pizza';
          } else if (fixed.containsKey(h)) {
            key = fixed[h]!;
          } else {
            key = today.removeLast();
          }
          slots.add(MapEntry(d0.add(Duration(hours: h)), key));
        }
        slots.add(MapEntry(d0.add(const Duration(hours: 20, minutes: 30)), 'ram')); // అమ్మా, నాకు జై శ్రీ రామ్ చెప్పు!
        for (final s in slots) {
          if (!s.key.isAfter(now.add(const Duration(seconds: 30)))) continue;
          final p = await _path(s.value);
          final file = File(p);
          final audio = Voice.i.hasClip(s.value)
              ? Voice.i.assetPath(s.value)
              : file.existsSync() && file.lengthSync() > 2000
                  ? p
                  : 'assets/audio/music_box.wav';
          final l = lines[s.value]!;
          await Alarm.set(
            alarmSettings: AlarmSettings(
              id: id,
              dateTime: s.key,
              assetAudioPath: audio,
              loopAudio: false,
              vibrate: false,
              androidFullScreenIntent: false,
              warningNotificationOnKill: false,
              volumeSettings: VolumeSettings.fade(volume: ((Store.i.settings['talkVol'] as num?)?.toDouble() ?? 0.8), fadeDuration: const Duration(milliseconds: 600), volumeEnforced: false),
              notificationSettings: NotificationSettings(title: l[3], body: '${Store.i.babyName} is talking to you 👶 Tap to reply', stopButton: 'OK 😘', iconColor: const Color(0xFFEE5D8E)),
            ),
          );
          plan['$id'] = s.value;
          id++;
        }
      }
      await Store.i.setSetting('talkPlan', plan);
    } catch (_) {}
  }

  /// Plays one sentence now (for the "Try it" button).
  static Future<void> test([String? key]) async {
    final k = key ?? (lines.keys.toList()..shuffle()).first;
    final l = lines[k]!;
    if (!await Voice.i.clip(k, volume: (Store.i.settings['talkVol'] as num?)?.toDouble() ?? 0.8)) await Voice.i.say(l[0], dev: l[1], lat: l[2], pitch: 1.85);
  }

  static String group(String key) => key.startsWith('f_') ? key : key == 'gm' ? 'gm' : (key == 'ram' || key == 'gn') ? 'ram' : (key == 'biryani' || key == 'pizza') ? 'food' : 'ask';
}

/// The little sheet shown in the app when the baby talks (if the app is open).
Future<void> showTalkSheet(BuildContext context, int id) async {
  final key = Talk.keyFor(id) ?? 'amma';
  final l = Talk.lines[key]!;
  final reps = Talk.replies[Talk.group(key)]!;
  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('👶', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 6),
          Text(l[3].replaceAll(RegExp(r'^\S+\s'), ''), textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: reps
                .map((r) => FilledButton.tonal(
                      onPressed: () async {
                        Navigator.pop(c);
                        try {
                          await Alarm.stop(id);
                        } catch (_) {}
                        if (!await Voice.i.clip(r[2])) await Voice.i.say(r[1], pitch: 1.85);
                      },
                      child: Text(r[0]),
                    ))
                .toList(),
          ),
        ]),
      ),
    ),
  );
}
