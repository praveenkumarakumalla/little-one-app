/// Pregnancy week by week: (week, size en, size te, length, weight, growth en, growth te).
/// Sizes are typical averages; every baby grows at its own pace.
const pregWeeks = <(int, String, String, String, String, String, String)>[
  (4, 'a poppy seed', 'గసగసాల గింజంత', '0.1 cm', '', 'A tiny ball of cells settles into the womb.', 'చిన్న కణాల గుండు గర్భసంచిలో స్థిరపడుతుంది.'),
  (5, 'a sesame seed', 'నువ్వు గింజంత', '0.2 cm', '', 'The heart and brain begin to form.', 'గుండె, మెదడు ఏర్పడటం మొదలవుతుంది.'),
  (6, 'a lentil', 'కందిపప్పు గింజంత', '0.6 cm', '', 'A heartbeat may be seen on a scan.', 'స్కాన్‌లో గుండె చప్పుడు కనిపించవచ్చు.'),
  (7, 'a jamun', 'నేరేడు పండంత', '1.3 cm', '', 'Little buds for arms and legs appear.', 'చేతులు, కాళ్ళకు చిన్న మొగ్గలు వస్తాయి.'),
  (8, 'a regi pandu (ber)', 'రేగి పండంత', '1.6 cm', '', 'Fingers and toes start to form.', 'వేళ్ళు, కాలి వేళ్ళు ఏర్పడుతున్నాయి.'),
  (9, 'a cherry', 'చెర్రీ పండంత', '2.3 cm', '', 'The baby starts tiny movements you cannot feel yet.', 'బిడ్డ చిన్న కదలికలు మొదలుపెడుతుంది, మీకు ఇంకా తెలియదు.'),
  (10, 'a date (kharjuram)', 'ఖర్జూరమంత', '3.1 cm', '', 'All the main organs are now in place.', 'ముఖ్యమైన అవయవాలన్నీ ఏర్పడ్డాయి.'),
  (11, 'a fig (anjeer)', 'అంజీర పండంత', '4.1 cm', '', 'Tiny hands open and close.', 'చిన్ని చేతులు తెరుస్తూ మూస్తున్నాయి.'),
  (12, 'a lime', 'నిమ్మకాయంత', '5.4 cm', '14 g', 'Reflexes begin. Time for the NT scan (11 to 14 weeks).', 'రిఫ్లెక్స్‌లు మొదలవుతాయి. NT స్కాన్ సమయం (11 నుంచి 14 వారాలు).'),
  (13, 'a sapota (chikoo)', 'సపోటా అంత', '7.4 cm', '23 g', 'Fingerprints are forming.', 'వేలిముద్రలు ఏర్పడుతున్నాయి.'),
  (14, 'a guava', 'జామకాయంత', '8.7 cm', '43 g', 'The baby can make little faces.', 'బిడ్డ చిన్న చిన్న ముఖ కవళికలు చేస్తుంది.'),
  (15, 'an apple', 'ఆపిల్ అంత', '10 cm', '70 g', 'The baby can sense light through the belly.', 'పొట్ట ద్వారా వెలుతురును గుర్తిస్తుంది.'),
  (16, 'a pomegranate', 'దానిమ్మ పండంత', '11.6 cm', '100 g', 'Ears are growing; soon the baby hears sounds.', 'చెవులు పెరుగుతున్నాయి; త్వరలో శబ్దాలు వింటుంది.'),
  (17, 'a custard apple', 'సీతాఫలమంత', '13 cm', '140 g', 'A little fat starts to form under the skin.', 'చర్మం కింద కొంచెం కొవ్వు ఏర్పడుతుంది.'),
  (18, 'a capsicum', 'క్యాప్సికమంత', '14.2 cm', '190 g', 'The baby can hear your heartbeat and your voice.', 'మీ గుండె చప్పుడు, మీ గొంతు వింటుంది.'),
  (19, 'a mango', 'మామిడి పండంత', '15.3 cm', '240 g', 'A creamy coat (vernix) protects the skin.', 'తెల్లటి పూత (వెర్నిక్స్) చర్మాన్ని కాపాడుతుంది.'),
  (20, 'a banana', 'అరటి పండంత', '25 cm', '300 g', 'Halfway! Time for the anomaly scan (18 to 22 weeks).', 'సగం దూరం వచ్చేశాం! అనామలీ స్కాన్ సమయం (18 నుంచి 22 వారాలు).'),
  (21, 'a carrot', 'క్యారెట్ అంత', '26.7 cm', '360 g', 'You may feel clear kicks now.', 'ఇప్పుడు తన్నులు స్పష్టంగా తెలియవచ్చు.'),
  (22, 'a small papaya', 'చిన్న బొప్పాయంత', '27.8 cm', '430 g', 'The baby can feel touch and grip.', 'స్పర్శ తెలుస్తుంది, పట్టుకోగలదు.'),
  (23, 'a Banganapalli mango', 'బంగినపల్లి మామిడంత', '28.9 cm', '500 g', 'Loud sounds can make the baby jump.', 'పెద్ద శబ్దాలకు ఉలిక్కిపడుతుంది.'),
  (24, 'a corn cob', 'మొక్కజొన్న కంకంత', '30 cm', '600 g', 'The lungs are developing.', 'ఊపిరితిత్తులు అభివృద్ధి చెందుతున్నాయి.'),
  (25, 'a radish', 'ముల్లంగంత', '34.6 cm', '660 g', 'Hair is growing on the head.', 'తల మీద జుట్టు పెరుగుతోంది.'),
  (26, 'a cauliflower', 'కాలీఫ్లవర్ అంత', '35.6 cm', '760 g', 'The eyes begin to open.', 'కళ్ళు తెరవడం మొదలవుతుంది.'),
  (27, 'a cabbage', 'క్యాబేజీ అంత', '36.6 cm', '875 g', 'Sleep and wake times begin; you may feel hiccups.', 'నిద్ర, మెలకువ సమయాలు మొదలవుతాయి; ఎక్కిళ్ళు తెలియవచ్చు.'),
  (28, 'a big brinjal', 'పెద్ద వంకాయంత', '37.6 cm', '1 kg', 'Third trimester! Count kicks every day.', 'మూడో త్రైమాసికం! రోజూ తన్నులు లెక్కపెట్టండి.'),
  (29, 'a bottle gourd', 'సొరకాయంత', '38.6 cm', '1.15 kg', 'Bones are getting stronger.', 'ఎముకలు గట్టిపడుతున్నాయి.'),
  (30, 'a cucumber (dosakaya)', 'దోసకాయంత', '39.9 cm', '1.3 kg', 'The brain is growing fast.', 'మెదడు వేగంగా పెరుగుతోంది.'),
  (31, 'a coconut', 'కొబ్బరికాయంత', '41.1 cm', '1.5 kg', 'The baby turns the head from side to side.', 'తలను పక్కలకు తిప్పుతుంది.'),
  (32, 'a pineapple', 'అనాసపండంత', '42.4 cm', '1.7 kg', 'The baby practises breathing; many are head-down now.', 'ఊపిరి పీల్చడం సాధన చేస్తుంది; చాలా మంది తల కిందకి తిరుగుతారు.'),
  (33, 'a small ash gourd', 'చిన్న బూడిద గుమ్మడంత', '43.7 cm', '1.9 kg', 'Bones harden; the skull stays soft for birth.', 'ఎముకలు గట్టిపడతాయి; పుట్టుక కోసం తల ఎముక మెత్తగానే ఉంటుంది.'),
  (34, 'a musk melon', 'కర్బూజంత', '45 cm', '2.1 kg', 'Fingernails reach the fingertips.', 'గోళ్ళు వేళ్ళ చివరి వరకు పెరుగుతాయి.'),
  (35, 'a small jackfruit', 'చిన్న పనసకాయంత', '46.2 cm', '2.4 kg', 'Space is getting tight; kicks feel like rolls.', 'చోటు తగ్గుతోంది; తన్నులు దొర్లినట్టు అనిపిస్తాయి.'),
  (36, 'a big papaya', 'పెద్ద బొప్పాయంత', '47.4 cm', '2.6 kg', 'Gaining fat every day. Pack the hospital bag.', 'రోజూ బరువు పెరుగుతోంది. హాస్పిటల్ బ్యాగ్ సిద్ధం చేయండి.'),
  (37, 'a pumpkin', 'గుమ్మడికాయంత', '48.6 cm', '2.9 kg', 'Early term. The baby practises sucking.', 'దాదాపు పూర్తి కాలం. పాలు చీకడం సాధన చేస్తుంది.'),
  (38, 'a jackfruit', 'పనసపండంత', '49.8 cm', '3.1 kg', 'The lungs are nearly ready.', 'ఊపిరితిత్తులు దాదాపు సిద్ధం.'),
  (39, 'a small watermelon', 'చిన్న పుచ్చకాయంత', '50.7 cm', '3.3 kg', 'Full term. Any day now!', 'పూర్తి కాలం. ఏ రోజైనా రావచ్చు!'),
  (40, 'a watermelon', 'పుచ్చకాయంత', '51.2 cm', '3.4 kg', 'Due date week. Few babies come exactly on the due date.', 'డ్యూ డేట్ వారం. చాలా తక్కువ మంది సరిగ్గా ఆ రోజే పుడతారు.'),
];

/// Checkups, scans and vaccines in pregnancy: (from week, to week, en, te).
const pregCheckups = <(int, int, String, String)>[
  (6, 12, 'Register the pregnancy at a doctor or government centre; first blood tests; start folic acid', 'డాక్టర్ లేదా ప్రభుత్వ కేంద్రంలో గర్భం నమోదు; మొదటి రక్త పరీక్షలు; ఫోలిక్ యాసిడ్ మొదలు'),
  (6, 9, 'Dating scan (confirms due date)', 'డేటింగ్ స్కాన్ (డ్యూ డేట్ నిర్ధారణ)'),
  (11, 14, 'NT scan and first-trimester screening', 'NT స్కాన్, మొదటి త్రైమాసిక పరీక్షలు'),
  (13, 20, 'Td vaccine (tetanus-diphtheria): dose 1, dose 2 four weeks later, or a booster', 'Td టీకా (ధనుర్వాతం-డిఫ్తీరియా): 1వ డోసు, 4 వారాల తర్వాత 2వ డోసు, లేదా బూస్టర్'),
  (14, 40, 'Iron-folic acid and calcium tablets daily, as advised', 'డాక్టర్ చెప్పినట్టు రోజూ ఐరన్-ఫోలిక్ యాసిడ్, కాల్షియం మాత్రలు'),
  (18, 22, 'Anomaly (TIFFA) scan', 'అనామలీ (TIFFA) స్కాన్'),
  (24, 28, 'Sugar test (glucose tolerance test)', 'షుగర్ పరీక్ష (గ్లూకోజ్ టాలరెన్స్ టెస్ట్)'),
  (28, 32, 'Growth scan; blood pressure and haemoglobin check', 'గ్రోత్ స్కాన్; బీపీ, హిమోగ్లోబిన్ పరీక్ష'),
  (36, 40, 'Weekly checkups; position of the baby; birth plan', 'వారానికొకసారి చెకప్; బిడ్డ స్థానం; ప్రసవ ప్రణాళిక'),
];

const pregDanger = [
  ('Bleeding or leaking water from the vagina', 'యోని నుంచి రక్తస్రావం లేదా నీరు కారడం'),
  ('Severe headache, blurred vision or swelling of face and hands', 'తీవ్రమైన తలనొప్పి, మసక చూపు లేదా ముఖం, చేతుల వాపు'),
  ('Baby moving much less than usual (after 28 weeks)', 'బిడ్డ కదలికలు మామూలు కంటే చాలా తక్కువ (28 వారాల తర్వాత)'),
  ('Fever, fits, severe belly pain or vomiting everything', 'జ్వరం, ఫిట్స్, తీవ్రమైన కడుపు నొప్పి లేదా తిన్నదంతా వాంతి'),
  ('Regular contractions before 37 weeks', '37 వారాల ముందే క్రమంగా నొప్పులు'),
];

const hospitalBag = [
  ('Hospital file, scan reports, Aadhaar, MCP card', 'హాస్పిటల్ ఫైల్, స్కాన్ రిపోర్టులు, ఆధార్, MCP కార్డు'),
  ('2–3 loose nighties or front-open dresses', '2–3 వదులు నైటీలు లేదా ముందు తెరిచే డ్రెస్సులు'),
  ('Maternity pads, cotton underwear, nursing bra', 'మెటర్నిటీ ప్యాడ్లు, నూలు లోదుస్తులు, నర్సింగ్ బ్రా'),
  ('Soft cotton baby clothes, cap, socks, mittens', 'మెత్తటి నూలు బిడ్డ బట్టలు, టోపీ, సాక్సులు, చేతి తొడుగులు'),
  ('Cotton swaddle cloths (old soft sarees work well)', 'నూలు చుట్టు గుడ్డలు (పాత మెత్తటి చీరలు బాగుంటాయి)'),
  ('Newborn diapers and soft cotton', 'నవజాత శిశువు డైపర్లు, మెత్తటి దూది'),
  ('Slippers, shawl, water bottle, phone charger', 'చెప్పులు, శాలువా, నీళ్ళ సీసా, ఫోన్ ఛార్జర్'),
  ('Snacks for the family (dry fruits, biscuits)', 'కుటుంబానికి స్నాక్స్ (డ్రై ఫ్రూట్స్, బిస్కెట్లు)'),
];
