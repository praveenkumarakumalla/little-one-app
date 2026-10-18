# -*- coding: utf-8 -*-
"""Guide books for new parents (English + Telugu), for parents of a baby girl and of a baby boy.
Mainstream advice (WHO / Indian Academy of Paediatrics). Written as general guidance, not medical advice.
make_guides.py turns this into assets/trial/guides.json (shown in the app) and PDF books."""

# Each chapter: key, for ('all' | 'girl' | 'boy'), title {en, te}, items: list of (heading, text) per language.
CHAPTERS = [
    {
        "key": "welcome", "for": "all",
        "title": {"en": "Welcome, new parents", "te": "కొత్త తల్లిదండ్రులకు స్వాగతం"},
        "en": [
            ("", "Congratulations on your little one! This book walks with you through the first year, one month at a time. Keep it simple: feed, sleep, love, and ask your doctor whenever you are unsure."),
            ("How to use this book", "Read the chapter for your baby's age. Mark vaccine dates. Show the danger-signs page to everyone who looks after the baby."),
            ("A promise", "Every baby is different. If your baby does something a little earlier or later than this book says, that is usually normal. Your doctor knows your baby best."),
        ],
        "te": [
            ("", "మీ చిన్నారి పుట్టినందుకు అభినందనలు! ఈ పుస్తకం మొదటి సంవత్సరం అంతా, నెల నెలా మీతో పాటు నడుస్తుంది. సులభంగా ఉంచండి: పాలు, నిద్ర, ప్రేమ. సందేహం వస్తే డాక్టర్‌ని అడగండి."),
            ("ఈ పుస్తకాన్ని ఎలా వాడాలి", "బిడ్డ వయసుకు తగిన అధ్యాయం చదవండి. టీకా తేదీలు గుర్తు పెట్టుకోండి. ప్రమాద సంకేతాల పేజీని బిడ్డను చూసుకునే అందరికీ చూపించండి."),
            ("ఒక మాట", "ప్రతి బిడ్డ వేరు. ఈ పుస్తకంలో చెప్పిన దానికంటే కొంచెం ముందో వెనకో ఏదైనా చేస్తే, అది సాధారణంగా మామూలే. మీ బిడ్డ గురించి మీ డాక్టర్‌కే బాగా తెలుసు."),
        ],
    },
    {
        "key": "first_week", "for": "all",
        "title": {"en": "The first week", "te": "మొదటి వారం"},
        "en": [
            ("Feeding", "Start breastfeeding within the first hour. The first yellow milk (colostrum) is precious: it protects the baby. Feed 8 to 12 times a day, whenever the baby shows hunger signs."),
            ("Only milk", "Give only breast milk (or formula if your doctor advises) for 6 months. No water, honey, gripe water, janam ghutti or sugar water."),
            ("Cord care", "Keep the cord stump clean and dry. Do not put oil, powder, turmeric or anything else on it. It falls off by itself in 1 to 2 weeks."),
            ("Jaundice", "Many babies look a little yellow on days 2 to 5. See a doctor quickly if the yellow appears in the first 24 hours, spreads to the legs and feet, or the baby is very sleepy and not feeding."),
            ("Bathing", "Sponge baths until the cord falls off. Keep the room warm. Never put oil in the nose or ears, and no kajal in the eyes."),
            ("Wet nappies", "From day 5, expect at least 6 wet nappies a day. This tells you the baby is getting enough milk."),
        ],
        "te": [
            ("పాలు", "పుట్టిన మొదటి గంటలోనే తల్లిపాలు మొదలుపెట్టండి. మొదటి పసుపు పాలు (ముర్రుపాలు) చాలా విలువైనవి: అవి బిడ్డను కాపాడతాయి. రోజుకు 8 నుంచి 12 సార్లు, బిడ్డకు ఆకలి సంకేతాలు కనిపించినప్పుడల్లా పాలు ఇవ్వండి."),
            ("పాలు మాత్రమే", "6 నెలల వరకు తల్లిపాలు మాత్రమే (డాక్టర్ చెబితే ఫార్ములా). నీళ్ళు, తేనె, గ్రైప్ వాటర్, జన్మ ఘుట్టి, చక్కెర నీళ్ళు ఇవ్వకండి."),
            ("బొడ్డు తాడు", "బొడ్డు తాడును శుభ్రంగా, పొడిగా ఉంచండి. నూనె, పౌడర్, పసుపు ఏదీ రాయకండి. 1 నుంచి 2 వారాల్లో అదే ఊడిపోతుంది."),
            ("కామెర్లు", "చాలా మంది పిల్లలు 2 నుంచి 5 రోజుల మధ్య కొంచెం పసుపుగా కనిపిస్తారు. మొదటి 24 గంటల్లోనే పసుపు వస్తే, కాళ్ళు అరికాళ్ళ వరకు వ్యాపిస్తే, లేదా బిడ్డ బాగా నిద్రపోతూ పాలు తాగకపోతే వెంటనే డాక్టర్‌ని చూడండి."),
            ("స్నానం", "బొడ్డు తాడు ఊడే వరకు తడి గుడ్డతో తుడవండి. గది వెచ్చగా ఉంచండి. ముక్కులో, చెవుల్లో నూనె వేయకండి. కళ్ళకు కాటుక పెట్టకండి."),
            ("తడి డైపర్లు", "5వ రోజు నుంచి రోజుకు కనీసం 6 తడి డైపర్లు ఉండాలి. అంటే బిడ్డకు సరిపడా పాలు అందుతున్నాయి."),
        ],
    },
    {
        "key": "sleep", "for": "all",
        "title": {"en": "Safe sleep", "te": "సురక్షితమైన నిద్ర"},
        "en": [
            ("Back to sleep", "Always put the baby to sleep on the back, on a firm flat surface. This lowers the risk of sudden infant death."),
            ("Keep the bed clear", "No pillows, soft toys or thick blankets near the face. A light cotton cloth is enough in Indian weather."),
            ("Close to you", "Let the baby sleep in your room, in a cradle or a separate space next to your bed, for the first 6 months."),
            ("How much", "Newborns sleep 14 to 17 hours a day in short stretches. Day and night settle slowly over 3 to 4 months."),
        ],
        "te": [
            ("వెల్లకిలా పడుకోబెట్టండి", "బిడ్డను ఎప్పుడూ వెల్లకిలా, గట్టిగా సమంగా ఉన్న చోట పడుకోబెట్టండి. దీనివల్ల ఆకస్మిక శిశు మరణం ప్రమాదం తగ్గుతుంది."),
            ("పక్క ఖాళీగా", "ముఖం దగ్గర దిండ్లు, బొమ్మలు, మందపాటి దుప్పట్లు వద్దు. మన వాతావరణానికి పలుచని నూలు గుడ్డ చాలు."),
            ("మీ దగ్గరే", "మొదటి 6 నెలలు బిడ్డ మీ గదిలోనే, ఉయ్యాలలో లేదా మీ మంచం పక్కన వేరే చోట పడుకోవాలి."),
            ("ఎంత నిద్ర", "పసిపిల్లలు రోజుకు 14 నుంచి 17 గంటలు, కొంచెం కొంచెం నిద్రపోతారు. పగలు రాత్రి తేడా 3 నుంచి 4 నెలల్లో నెమ్మదిగా వస్తుంది."),
        ],
    },
    {
        "key": "crying", "for": "all",
        "title": {"en": "Crying and soothing", "te": "ఏడుపు, ఓదార్పు"},
        "en": [
            ("Why babies cry", "Hunger, a wet nappy, wind, tiredness, too hot or cold, or just wanting to be held. Check these one by one."),
            ("Soothing", "Hold the baby close, swaddle snugly, rock gently, make a soft 'shhh' sound near the ear, or offer a feed. Burp after every feed."),
            ("Colic", "Some healthy babies cry for hours in the evening between 2 weeks and 4 months. It passes. Take turns with family so nobody gets exhausted."),
            ("Never shake", "If you feel angry or overwhelmed, put the baby down safely in the cradle and step away for a few minutes. Never shake a baby."),
        ],
        "te": [
            ("పిల్లలు ఎందుకు ఏడుస్తారు", "ఆకలి, తడి డైపర్, గ్యాస్, అలసట, వేడి లేదా చలి, లేదా ఎత్తుకోమని. ఒక్కొక్కటిగా చూడండి."),
            ("ఓదార్పు", "దగ్గరగా ఎత్తుకోండి, గుడ్డలో గట్టిగా చుట్టండి, నెమ్మదిగా ఊపండి, చెవి దగ్గర మెల్లగా 'ష్ ష్' అనండి, లేదా పాలు ఇవ్వండి. ప్రతిసారి పాలు తాగిన తర్వాత త్రేన్పు తీయించండి."),
            ("కోలిక్", "కొంతమంది ఆరోగ్యంగా ఉన్న పిల్లలు 2 వారాల నుంచి 4 నెలల మధ్య సాయంత్రం గంటల తరబడి ఏడుస్తారు. ఇది తగ్గిపోతుంది. ఎవరూ అలసిపోకుండా కుటుంబంలో వంతులు వేసుకోండి."),
            ("ఎప్పుడూ ఊపేయకండి", "కోపం లేదా ఒత్తిడి వస్తే, బిడ్డను ఉయ్యాలలో సురక్షితంగా పడుకోబెట్టి కొన్ని నిమిషాలు బయటకు వెళ్ళండి. బిడ్డను ఎప్పుడూ గట్టిగా కుదపకండి."),
        ],
    },
    {
        "key": "girl_care", "for": "girl",
        "title": {"en": "Caring for your baby girl", "te": "మీ పాప సంరక్షణ"},
        "en": [
            ("Cleaning", "Always wipe from front to back when changing nappies. This keeps germs away from the urine passage. Use plain water and soft cotton."),
            ("Normal in the first weeks", "A little white discharge, or even a few drops of blood from the vagina in the first 1 to 2 weeks, is common. It comes from the mother's hormones and stops by itself."),
            ("Swollen breasts", "Small breast swelling, sometimes with a drop of milk, can happen in girls and boys. Do not squeeze or massage it; it settles in a few weeks."),
            ("Raising a confident girl", "Give her the same food, attention, play and dreams as any child. Read to her, praise her effort, and let her explore. Confidence begins in the cradle."),
            ("Body safety later", "From around 3 years, teach the correct names of body parts and simple rules: nobody touches your private parts, and you can always tell amma or nanna."),
            ("Saving for her", "Sukanya Samriddhi Yojana is a government savings scheme for girls under 10. Check the current interest rate at a post office or bank."),
        ],
        "te": [
            ("శుభ్రం చేయడం", "డైపర్ మార్చేటప్పుడు ఎప్పుడూ ముందు నుంచి వెనక్కి తుడవండి. దీనివల్ల మూత్ర మార్గానికి క్రిములు చేరవు. మామూలు నీళ్ళు, మెత్తటి దూది వాడండి."),
            ("మొదటి వారాల్లో మామూలే", "మొదటి 1 నుంచి 2 వారాల్లో కొంచెం తెల్లటి స్రావం, లేదా కొన్ని చుక్కల రక్తం కూడా రావచ్చు. ఇది తల్లి హార్మోన్ల వల్ల వస్తుంది, దానంతట అదే ఆగిపోతుంది."),
            ("రొమ్ముల వాపు", "ఆడపిల్లలకీ మగపిల్లలకీ రొమ్ములు కొంచెం ఉబ్బవచ్చు, ఒక్కోసారి పాల చుక్క కూడా రావచ్చు. పిండకండి, మర్దన చేయకండి; కొన్ని వారాల్లో తగ్గిపోతుంది."),
            ("ధైర్యమైన అమ్మాయిగా పెంచడం", "ఏ బిడ్డకైనా ఇచ్చేంత ఆహారం, శ్రద్ధ, ఆట, కలలు ఆమెకూ ఇవ్వండి. కథలు చదివి వినిపించండి, ప్రయత్నాన్ని మెచ్చుకోండి, కొత్తవి తెలుసుకోనివ్వండి. ఆత్మవిశ్వాసం ఉయ్యాల నుంచే మొదలవుతుంది."),
            ("తర్వాత శరీర భద్రత", "సుమారు 3 ఏళ్ళ నుంచి శరీర భాగాల సరైన పేర్లు, సులభమైన నియమాలు నేర్పండి: నీ ప్రైవేట్ భాగాలను ఎవరూ తాకకూడదు, ఏదైనా అమ్మకో నాన్నకో ఎప్పుడైనా చెప్పొచ్చు."),
            ("ఆమె కోసం పొదుపు", "సుకన్య సమృద్ధి యోజన 10 ఏళ్ళ లోపు ఆడపిల్లల కోసం ప్రభుత్వ పొదుపు పథకం. ప్రస్తుత వడ్డీ రేటు పోస్టాఫీసు లేదా బ్యాంకులో తెలుసుకోండి."),
        ],
    },
    {
        "key": "boy_care", "for": "boy",
        "title": {"en": "Caring for your baby boy", "te": "మీ బాబు సంరక్షణ"},
        "en": [
            ("Cleaning", "Clean only the outside of the penis with plain water during nappy changes. Never pull back the foreskin; it separates naturally over years."),
            ("Nappy tip", "Point the penis downwards when closing the nappy to avoid leaks up the tummy."),
            ("Testes and swelling", "The doctor checks that both testes are in the scrotum. A soft fluid swelling of the scrotum (hydrocele) is common and usually goes away in the first year. See a doctor for a painful or hard swelling."),
            ("Swollen breasts", "Small breast swelling, sometimes with a drop of milk, can happen in boys and girls. Do not squeeze or massage it; it settles in a few weeks."),
            ("Raising a kind, confident boy", "Let him cry and show feelings; comfort him instead of saying 'boys don't cry'. Share chores and care as he grows, and model respect for everyone."),
            ("Body safety later", "From around 3 years, teach the correct names of body parts and simple rules: nobody touches your private parts, and you can always tell amma or nanna. Boys need this too."),
        ],
        "te": [
            ("శుభ్రం చేయడం", "డైపర్ మార్చేటప్పుడు పురుషాంగం బయటి భాగాన్ని మాత్రమే మామూలు నీళ్ళతో శుభ్రం చేయండి. ముందు చర్మాన్ని ఎప్పుడూ వెనక్కి లాగకండి; అది సంవత్సరాల్లో సహజంగా విడిపోతుంది."),
            ("డైపర్ చిట్కా", "డైపర్ వేసేటప్పుడు పురుషాంగాన్ని కిందకు ఉంచండి, అప్పుడు పొట్ట వైపు లీక్ అవ్వదు."),
            ("వృషణాలు, వాపు", "రెండు వృషణాలు సంచిలో ఉన్నాయో డాక్టర్ చూస్తారు. సంచిలో మెత్తటి నీటి వాపు (హైడ్రోసీల్) సాధారణం, సాధారణంగా మొదటి సంవత్సరంలో తగ్గిపోతుంది. నొప్పిగా లేదా గట్టిగా వాపు ఉంటే డాక్టర్‌ని చూడండి."),
            ("రొమ్ముల వాపు", "మగపిల్లలకీ ఆడపిల్లలకీ రొమ్ములు కొంచెం ఉబ్బవచ్చు, ఒక్కోసారి పాల చుక్క కూడా రావచ్చు. పిండకండి, మర్దన చేయకండి; కొన్ని వారాల్లో తగ్గిపోతుంది."),
            ("మంచి, ధైర్యమైన అబ్బాయిగా పెంచడం", "'మగపిల్లలు ఏడవకూడదు' అనకుండా, ఏడవనివ్వండి, భావాలు చెప్పనివ్వండి, ఓదార్చండి. పెరిగే కొద్దీ ఇంటి పనుల్లో, సంరక్షణలో భాగం చేయండి. అందరినీ గౌరవించడం మీరే చూపించండి."),
            ("తర్వాత శరీర భద్రత", "సుమారు 3 ఏళ్ళ నుంచి శరీర భాగాల సరైన పేర్లు, సులభమైన నియమాలు నేర్పండి: నీ ప్రైవేట్ భాగాలను ఎవరూ తాకకూడదు, ఏదైనా అమ్మకో నాన్నకో ఎప్పుడైనా చెప్పొచ్చు. ఇది అబ్బాయిలకూ అవసరం."),
        ],
    },
    {
        "key": "months", "for": "all",
        "title": {"en": "Month by month", "te": "నెల నెలా ఎదుగుదల"},
        "en": [
            ("Month 1", "Looks at faces, startles at loud sounds, lifts the head briefly on the tummy. Give a little tummy time every day while awake."),
            ("Month 2", "First real smiles, cooing sounds, follows your face with the eyes. Talk and sing to the baby a lot."),
            ("Month 3", "Holds the head steadier, opens hands, brings hands to the mouth, laughs. Day and night start to settle."),
            ("Month 4", "Holds and shakes a rattle, pushes up on the arms, may roll from tummy to back."),
            ("Month 5", "Reaches for toys, rolls both ways, knows familiar people, blows bubbles."),
            ("Month 6", "Sits with support, turns to its name, starts first foods with milk. Time for teeth care with a soft cloth when the first tooth comes."),
            ("Months 7 to 8", "Sits alone, passes toys between hands, babbles 'ba-ba', 'ma-ma'. May feel shy with strangers."),
            ("Months 9 to 10", "Crawls, pulls to stand, picks small things with finger and thumb. Keep coins and small objects out of reach."),
            ("Months 11 to 12", "Walks holding furniture, says 1 to 2 words, waves bye-bye, eats soft family food."),
            ("When to ask the doctor", "No smile by 3 months, not holding the head by 4 months, not sitting by 9 months, or losing a skill the baby already had."),
        ],
        "te": [
            ("1వ నెల", "ముఖాలను చూస్తుంది, పెద్ద శబ్దాలకు ఉలిక్కిపడుతుంది, బోర్లా పడుకున్నప్పుడు తల కొంచెం ఎత్తుతుంది. మెలకువగా ఉన్నప్పుడు రోజూ కొంచెం సేపు బోర్లా పడుకోబెట్టండి."),
            ("2వ నెల", "మొదటి నిజమైన నవ్వులు, 'ఊ ఆ' శబ్దాలు, మీ ముఖాన్ని కళ్ళతో అనుసరిస్తుంది. బిడ్డతో బాగా మాట్లాడండి, పాటలు పాడండి."),
            ("3వ నెల", "తల స్థిరంగా పట్టుకుంటుంది, చేతులు తెరుస్తుంది, చేతులు నోట్లో పెట్టుకుంటుంది, నవ్వుతుంది. పగలు రాత్రి తేడా వస్తుంది."),
            ("4వ నెల", "గిలక్కాయ పట్టుకుని ఊపుతుంది, చేతుల మీద లేస్తుంది, బోర్లా నుంచి వెల్లకిలా తిరగవచ్చు."),
            ("5వ నెల", "బొమ్మల కోసం చేయి చాపుతుంది, రెండు వైపులా దొర్లుతుంది, తెలిసినవాళ్ళను గుర్తుపడుతుంది."),
            ("6వ నెల", "ఆసరాతో కూర్చుంటుంది, పేరు పిలిస్తే తిరుగుతుంది, పాలతో పాటు మొదటి ఆహారం మొదలవుతుంది. మొదటి పన్ను వస్తే మెత్తటి గుడ్డతో శుభ్రం చేయండి."),
            ("7 నుంచి 8 నెలలు", "ఒంటరిగా కూర్చుంటుంది, బొమ్మను ఒక చేతి నుంచి మరో చేతికి మారుస్తుంది, 'బ బ', 'మ మ' అంటుంది. కొత్తవాళ్ళంటే బెరుకు రావచ్చు."),
            ("9 నుంచి 10 నెలలు", "పాకుతుంది, పట్టుకుని నిలబడుతుంది, చిన్న వస్తువులను వేళ్ళతో పట్టుకుంటుంది. నాణేలు, చిన్న వస్తువులు అందకుండా పెట్టండి."),
            ("11 నుంచి 12 నెలలు", "ఫర్నిచర్ పట్టుకుని నడుస్తుంది, 1 లేదా 2 మాటలు అంటుంది, టాటా చెబుతుంది, మెత్తటి ఇంటి భోజనం తింటుంది."),
            ("డాక్టర్‌ని ఎప్పుడు అడగాలి", "3 నెలలకు నవ్వకపోతే, 4 నెలలకు తల నిలపకపోతే, 9 నెలలకు కూర్చోకపోతే, లేదా ఇదివరకు చేసిన పని మానేస్తే."),
        ],
    },
    {
        "key": "vaccines", "for": "all",
        "title": {"en": "Vaccines", "te": "టీకాలు"},
        "en": [
            ("Why", "Vaccines protect your baby from serious diseases. Government centres give the main vaccines free under the Universal Immunisation Programme."),
            ("Schedule (IAP)", "Birth: BCG, OPV 0, Hepatitis B 1. 6, 10 and 14 weeks: DTP, IPV, Hepatitis B, Hib, Rotavirus, PCV. 6 and 7 months: Influenza, Typhoid. 9 months: MMR 1. 12 months: Hepatitis A. 15 months: MMR 2, Varicella, PCV booster. 16 to 18 months: DTP, Hib and IPV boosters."),
            ("After a vaccine", "Mild fever, fussiness or soreness for a day is common. Ask your doctor about paracetamol drops and the right dose. Keep the vaccination card safe; the app reminds you of each date."),
        ],
        "te": [
            ("ఎందుకు", "టీకాలు బిడ్డను తీవ్రమైన వ్యాధుల నుంచి కాపాడతాయి. ప్రభుత్వ కేంద్రాల్లో ముఖ్యమైన టీకాలు సార్వత్రిక టీకా కార్యక్రమం కింద ఉచితంగా ఇస్తారు."),
            ("టీకాల పట్టిక (IAP)", "పుట్టినప్పుడు: BCG, OPV 0, హెపటైటిస్ B 1. 6, 10, 14 వారాలు: DTP, IPV, హెపటైటిస్ B, Hib, రోటావైరస్, PCV. 6, 7 నెలలు: ఇన్ఫ్లుయెంజా, టైఫాయిడ్. 9 నెలలు: MMR 1. 12 నెలలు: హెపటైటిస్ A. 15 నెలలు: MMR 2, ఆటలమ్మ, PCV బూస్టర్. 16 నుంచి 18 నెలలు: DTP, Hib, IPV బూస్టర్లు."),
            ("టీకా తర్వాత", "ఒక రోజు కొంచెం జ్వరం, చిరాకు, నొప్పి సాధారణం. పారాసెటమాల్ చుక్కలు, సరైన మోతాదు గురించి డాక్టర్‌ని అడగండి. టీకా కార్డును జాగ్రత్తగా ఉంచండి; యాప్ ప్రతి తేదీని గుర్తు చేస్తుంది."),
        ],
    },
    {
        "key": "food", "for": "all",
        "title": {"en": "First foods from 6 months", "te": "6 నెలల నుంచి మొదటి ఆహారం"},
        "en": [
            ("Start", "At 6 months, keep breast milk and add soft home food 2 to 3 times a day, a few spoons at first."),
            ("Good first foods", "Rice kanji, ragi java, dal water then mashed dal, soft khichdi with ghee, mashed banana, stewed apple, mashed vegetables like carrot and pumpkin."),
            ("Avoid under 1 year", "No salt, sugar or honey. No cow's milk as the main drink (small amounts in food are fine). No whole nuts or hard pieces that can choke."),
            ("Water", "Small sips of boiled and cooled water with meals from 6 months."),
            ("Hygiene", "Wash hands, use clean bowls, and give freshly made food. Throw away leftovers the baby has eaten from."),
        ],
        "te": [
            ("మొదలు", "6 నెలలకు తల్లిపాలు కొనసాగిస్తూ, రోజుకు 2 నుంచి 3 సార్లు మెత్తటి ఇంటి ఆహారం, మొదట కొన్ని చెంచాలు ఇవ్వండి."),
            ("మంచి మొదటి ఆహారాలు", "అన్నం గంజి, రాగి జావ, పప్పు నీళ్ళు తర్వాత మెదిపిన పప్పు, నెయ్యితో మెత్తటి కిచిడీ, మెదిపిన అరటిపండు, ఉడికించిన ఆపిల్, క్యారెట్ గుమ్మడి లాంటి మెదిపిన కూరగాయలు."),
            ("1 సంవత్సరం లోపు వద్దు", "ఉప్పు, చక్కెర, తేనె వద్దు. ఆవు పాలు ముఖ్య పానీయంగా వద్దు (ఆహారంలో కొంచెం పర్వాలేదు). పూర్తి గింజలు, గొంతులో ఇరుక్కునే గట్టి ముక్కలు వద్దు."),
            ("నీళ్ళు", "6 నెలల నుంచి భోజనంతో పాటు కాచి చల్లార్చిన నీళ్ళు కొంచెం కొంచెం ఇవ్వండి."),
            ("శుభ్రత", "చేతులు కడుక్కోండి, శుభ్రమైన గిన్నెలు వాడండి, అప్పుడే చేసిన ఆహారం ఇవ్వండి. బిడ్డ తిన్న తర్వాత మిగిలింది పారేయండి."),
        ],
    },
    {
        "key": "danger", "for": "all",
        "title": {"en": "Danger signs: see a doctor now", "te": "ప్రమాద సంకేతాలు: వెంటనే డాక్టర్"},
        "en": [
            ("Go to a doctor or hospital immediately if the baby", "has fever in the first 3 months (38°C / 100.4°F or more), or feels very cold; is not feeding or vomits everything; has fast or difficult breathing, or the chest pulls in; has fits (convulsions); is very sleepy or hard to wake; has yellow palms or soles; has a red, swollen or smelly cord; has blood in the stool; has very few wet nappies or a sunken soft spot on the head."),
            ("Keep ready", "Your doctor's number, the nearest hospital's address, and 108 for an ambulance."),
        ],
        "te": [
            ("బిడ్డకు ఇలా ఉంటే వెంటనే డాక్టర్ దగ్గరకు లేదా హాస్పిటల్‌కు వెళ్ళండి", "మొదటి 3 నెలల్లో జ్వరం (38°C / 100.4°F లేదా ఎక్కువ), లేదా ఒళ్ళు బాగా చల్లగా ఉంటే; పాలు తాగకపోతే లేదా తాగినదంతా వాంతి చేసుకుంటే; ఊపిరి వేగంగా లేదా కష్టంగా తీసుకుంటే, ఛాతీ లోపలికి లాగుతుంటే; ఫిట్స్ (మూర్ఛ) వస్తే; బాగా నిద్రమత్తుగా ఉండి లేపినా లేవకపోతే; అరచేతులు అరికాళ్ళు పసుపుగా ఉంటే; బొడ్డు ఎర్రగా, వాచి, దుర్వాసన వస్తే; మలంలో రక్తం ఉంటే; తడి డైపర్లు చాలా తక్కువగా ఉంటే లేదా తల మీద మెత్తటి భాగం లోతుగా ఉంటే."),
            ("సిద్ధంగా ఉంచుకోండి", "మీ డాక్టర్ నంబర్, దగ్గరలోని హాస్పిటల్ అడ్రస్, అంబులెన్స్ కోసం 108."),
        ],
    },
    {
        "key": "amma", "for": "all",
        "title": {"en": "Caring for amma", "te": "అమ్మ సంరక్షణ"},
        "en": [
            ("Rest and food", "Sleep when the baby sleeps. Eat home food with dal, vegetables, fruit and plenty of water. Let family handle cooking and visitors."),
            ("Baby blues", "Feeling teary or low in the first 2 weeks is common and passes."),
            ("When it is more", "If sadness, worry or no interest in anything lasts more than 2 weeks, or you have thoughts of harming yourself or the baby, talk to your doctor today. Postpartum depression is common and treatable."),
            ("Nanna and family", "Take night turns, burp and change the baby, and give amma time to rest. Caring for amma is caring for the baby."),
        ],
        "te": [
            ("విశ్రాంతి, ఆహారం", "బిడ్డ నిద్రపోయినప్పుడు మీరూ నిద్రపోండి. పప్పు, కూరగాయలు, పండ్లతో ఇంటి భోజనం, నీళ్ళు బాగా తాగండి. వంట, అతిథులను కుటుంబం చూసుకోనివ్వండి."),
            ("బేబీ బ్లూస్", "మొదటి 2 వారాల్లో కన్నీళ్ళు రావడం, మనసు బాగోకపోవడం సాధారణం, తగ్గిపోతుంది."),
            ("ఇంకా ఎక్కువైతే", "బాధ, ఆందోళన, దేనిపైనా ఆసక్తి లేకపోవడం 2 వారాల కంటే ఎక్కువ ఉంటే, లేదా మిమ్మల్ని లేదా బిడ్డను బాధపెట్టే ఆలోచనలు వస్తే, ఈరోజే డాక్టర్‌తో మాట్లాడండి. ప్రసవానంతర డిప్రెషన్ సాధారణం, నయం అవుతుంది."),
            ("నాన్న, కుటుంబం", "రాత్రి వంతులు తీసుకోండి, త్రేన్పు తీయించండి, డైపర్ మార్చండి, అమ్మకు విశ్రాంతి ఇవ్వండి. అమ్మను చూసుకోవడమే బిడ్డను చూసుకోవడం."),
        ],
    },
    {
        "key": "schemes", "for": "all",
        "title": {"en": "Government schemes and savings", "te": "ప్రభుత్వ పథకాలు, పొదుపు"},
        "en": [
            ("PM Matru Vandana Yojana", "Rs 5,000 for the first child in two instalments, and Rs 6,000 more if the second child is a girl. Apply through your Anganwadi centre or ASHA worker with Aadhaar, bank account and the MCP card."),
            ("Documents for the baby", "Get the birth certificate early, then Baal Aadhaar. Most schemes need them."),
            ("Free care", "Free vaccines at government centres; Anganwadi services give nutrition support and growth checks for mothers and children under 6."),
            ("Savings plans", "Sukanya Samriddhi Yojana (girls under 10), Public Provident Fund, and NPS Vatsalya (from Rs 250 a year) are government-backed. Rates change every quarter; check at a post office or bank. This is information, not financial advice."),
        ],
        "te": [
            ("ప్రధాన మంత్రి మాతృ వందన యోజన", "మొదటి బిడ్డకు రెండు విడతల్లో రూ. 5,000, రెండో బిడ్డ ఆడపిల్ల అయితే మరో రూ. 6,000. ఆధార్, బ్యాంక్ ఖాతా, MCP కార్డుతో అంగన్‌వాడీ కేంద్రం లేదా ఆశా కార్యకర్త ద్వారా దరఖాస్తు చేయండి."),
            ("బిడ్డకు పత్రాలు", "ముందుగా జనన ధృవీకరణ పత్రం, తర్వాత బాల ఆధార్ తీసుకోండి. చాలా పథకాలకు ఇవి అవసరం."),
            ("ఉచిత సేవలు", "ప్రభుత్వ కేంద్రాల్లో ఉచిత టీకాలు; అంగన్‌వాడీ సేవలు తల్లులకు, 6 ఏళ్ళ లోపు పిల్లలకు పోషణ సహాయం, ఎదుగుదల పరీక్షలు ఇస్తాయి."),
            ("పొదుపు పథకాలు", "సుకన్య సమృద్ధి యోజన (10 ఏళ్ళ లోపు ఆడపిల్లలు), పబ్లిక్ ప్రావిడెంట్ ఫండ్, NPS వాత్సల్య (సంవత్సరానికి రూ. 250 నుంచి) ప్రభుత్వ మద్దతు ఉన్నవి. వడ్డీ రేట్లు ప్రతి త్రైమాసికం మారతాయి; పోస్టాఫీసు లేదా బ్యాంకులో తెలుసుకోండి. ఇది సమాచారం మాత్రమే, ఆర్థిక సలహా కాదు."),
        ],
    },
]

BOOK_TITLES = {
    "girl": {"en": "Our Baby Girl: The First Year", "te": "మా పాప: మొదటి సంవత్సరం"},
    "boy": {"en": "Our Baby Boy: The First Year", "te": "మా బాబు: మొదటి సంవత్సరం"},
}
NOTE = {
    "en": "General guidance based on WHO and Indian Academy of Paediatrics advice. Not a substitute for your doctor.",
    "te": "WHO, భారతీయ పీడియాట్రిక్స్ అకాడమీ సూచనల ఆధారంగా సాధారణ మార్గదర్శనం. డాక్టర్ సలహాకు ప్రత్యామ్నాయం కాదు.",
}
