import 'models.dart';

/// Four prepared Orkhon Valley sites. Published map locations were checked
/// against OSM in October 2026; sources are listed in docs/MAPS_SETUP.md.
/// Kharkhorin marks the town, not a surveyed route or archaeological entrance.
const demoSites = <Site>[
  Site(
    id: "kharkhorin",
    name: "Kharkhorin",
    nameMn: "Хархорин",
    summary:
        "The thirteenth-century Mongol capital, Karakorum, as the Flemish friar William of Rubruck saw it in 1254.",
    lat: 47.1975,
    lng: 102.8265,
    image: "assets/images/silver-tree.jpg",
    era: "Mongol Empire",
  ),
  Site(
    id: "erdene-zuu",
    name: "Erdene Zuu",
    nameMn: "Эрдэнэ Зуу",
    summary:
        "Mongolia's earliest surviving Buddhist monastery, founded in 1585 beside the ruins of Karakorum.",
    lat: 47.2017,
    lng: 102.8442,
    image: "assets/images/monastery.jpg",
    era: "Buddhist heritage",
  ),
  Site(
    id: "tovkhon",
    name: "Tövkhön",
    nameMn: "Төвхөн",
    summary:
        "Zanabazar's mountain hermitage, where he made sculpture and shaped the Soyombo script.",
    lat: 47.0129679,
    lng: 102.2558901,
    image: "assets/images/landscape.jpg",
    era: "Buddhist heritage",
  ),
  Site(
    id: "ulaan-tsutgalan",
    name: "Ulaan Tsutgalan",
    nameMn: "Улаан цутгалан",
    summary:
        "A waterfall cut through ancient lava, on the river that gave the Orkhon Valley its capitals.",
    lat: 46.7875,
    lng: 101.96,
    image: "assets/images/steppe.jpg",
    era: "Natural heritage",
  ),
];

const demoVoices = <DemoVoice>[
  DemoVoice(
    id: "samantha",
    name: "Samantha",
    description: "Clear · American English",
    systemVoice: "Samantha",
  ),
  DemoVoice(
    id: "daniel",
    name: "Daniel",
    description: "Measured · British English",
    systemVoice: "Daniel",
  ),
  DemoVoice(
    id: "karen",
    name: "Karen",
    description: "Warm · Australian English",
    systemVoice: "Karen",
  ),
  DemoVoice(
    id: "moira",
    name: "Moira",
    description: "Gentle · Irish English",
    systemVoice: "Moira",
  ),
];

const demoCitations = <Citation>[
  Citation(
    id: "rubruck-1900",
    title: "The Journey of William of Rubruck to the Eastern Parts of the World, 1253–55",
    author: "William of Rubruck, translated by W. W. Rockhill (Hakluyt Society, 1900)",
    page: "Public domain",
    note:
        "Rubruck's own account of his journey to the court of Möngke Khan. Story text is an editorial retelling of the cited pages, not a quotation.",
    url: "https://archive.org/details/journeyofwilliam00ruys",
  ),
  Citation(
    id: "unesco-orkhon",
    title: "Orkhon Valley Cultural Landscape",
    author: "UNESCO World Heritage Centre",
    page: "World Heritage List no. 1081 (2004)",
    note:
        "The listed landscape includes Kharkhorum, Erdene Zuu and the Tövkhön hermitage.",
    url: "https://whc.unesco.org/en/list/1081/",
  ),
  Citation(
    id: "wiki-erdene-zuu",
    title: "Erdene Zuu Monastery",
    author: "Wikipedia",
    page: "History",
    note:
        "Founding in 1585, reuse of Karakorum stones, the 108-stupa wall, and the damage of 1688 and 1939.",
    url: "https://en.wikipedia.org/wiki/Erdene_Zuu_Monastery",
  ),
  Citation(
    id: "wiki-tovkhon",
    title: "Tövkhön Monastery",
    author: "Wikipedia",
    page: "History",
    note:
        "Founding by Zanabazar in 1648, building from 1653, destruction in 1688, restoration in 1773 and 1997.",
    url: "https://en.wikipedia.org/wiki/T%C3%B6vkh%C3%B6n_Monastery",
  ),
  Citation(
    id: "wiki-zanabazar",
    title: "Zanabazar",
    author: "Wikipedia",
    page: "Artistic works · Soyombo script",
    note:
        "His workshop at Tövkhön in the 1670s–1680s and the Soyombo script of 1686.",
    url: "https://en.wikipedia.org/wiki/Zanabazar",
  ),
  Citation(
    id: "wiki-ulaan-tsutgalan",
    title: "Ulaan Tsutgalan Waterfall",
    author: "Wikipedia",
    page: "History · Geology",
    note:
        "Quaternary lava from the Tsagaan Azarga source; the falls are about 24 m high and 10 m wide.",
    url: "https://en.wikipedia.org/wiki/Orkhon_Waterfall",
  ),
  Citation(
    id: "wiki-orkhon-valley",
    title: "Orkhon Valley",
    author: "Wikipedia",
    page: "Significance · Sites",
    note:
        "Göktürk inscriptions of the 8th century, the Uyghur capital Ordu-Baliq and the Mongol capital Karakorum.",
    url: "https://en.wikipedia.org/wiki/Orkhon_Valley",
  ),
];

/// Source-based retellings; each "context" block links to its citation.
/// Text lives in tool/sourced_content.json, with matching narration assets.
const demoTemplates = <StoryTemplate>[
  StoryTemplate(
    id: "silver-tree",
    siteId: "kharkhorin",
    title: "The Silver Tree of Karakorum",
    subtitle: "Möngke Khan's palace, 1254 · Chapter I",
    image: "assets/images/silver-tree.jpg",
    chapter: 1,
    genre: "Legend · domog",
    style: "Lyrical",
    mood: "Noble & brave",
    seed: "A friar reaches Möngke Khan's palace and its silver fountain.",
    segments: [
      StorySegment(
        kind: "legend",
        text:
            "In the spring of 1254 a Flemish friar, William of Rubruck, followed the court of Möngke Khan to Karakorum. Beside the city wall stood the Khan's great palace, closed off by a high wall. Twice a year the Khan held his great drinking feasts there, and in summer nobles came from as far as two months' ride away.",
      ),
      StorySegment(
        kind: "legend",
        text:
            "At the palace entrance stood a tree made of silver by a goldsmith from Paris. Four silver lions at its roots poured mare's milk. Pipes inside the trunk carried wine, clarified mare's milk, honey mead and rice wine. When the butler called, a silver angel at the top lifted its trumpet, and the servants hidden below poured out the drinks.",
      ),
      StorySegment(
        kind: "context",
        text:
            "Rubruck saw the silver tree himself. Its maker was Guillaume Buchier, a Parisian goldsmith who had been taken captive and brought east.",
        citationId: "rubruck-1900-silver-tree",
      ),
    ],
    nextIds: ["workshop", "river-message"],
    citations: [
      Citation(
        id: "rubruck-1900-silver-tree",
        title: "The Journey of William of Rubruck to the Eastern Parts of the World, 1253–55",
        author: "William of Rubruck, translated by W. W. Rockhill (Hakluyt Society, 1900)",
        page: "pp. 207–208",
        note:
            "Rubruck's own account of his journey to the court of Möngke Khan. Story text is an editorial retelling of the cited pages, not a quotation.",
        url: "https://archive.org/details/journeyofwilliam00ruys",
      ),
    ],
  ),
  StoryTemplate(
    id: "workshop",
    siteId: "kharkhorin",
    title: "The Goldsmith from Paris",
    subtitle: "Guillaume Buchier · Chapter II",
    image: "assets/images/silver-tree.jpg",
    chapter: 2,
    genre: "Legend · domog",
    style: "Lyrical",
    mood: "Mysterious",
    seed: "Follow the Parisian goldsmith who built the silver tree.",
    segments: [
      StorySegment(
        kind: "legend",
        text:
            "On the road east, a woman from Metz who had been taken captive told Rubruck about a master goldsmith in Karakorum named William. He came from Paris. His family name was Buchier, his father was Laurent Buchier, and she believed a brother, Roger, still lived on the Grand Pont in Paris.",
      ),
      StorySegment(
        kind: "legend",
        text:
            "In Karakorum, Rubruck found that the goldsmith had made the silver tree for Möngke's palace. Buchier supported a young man he treated as a son, who served as an excellent interpreter. Far from France, a captive craftsman had become one of the makers of the Khan's court.",
      ),
      StorySegment(
        kind: "context",
        text:
            "In his notes, Rockhill suggests that Buchier was probably captured around 1242, during the Mongol campaigns in Europe.",
        citationId: "rubruck-1900-workshop",
      ),
    ],
    nextIds: ["steppe-return"],
    citations: [
      Citation(
        id: "rubruck-1900-workshop",
        title: "The Journey of William of Rubruck to the Eastern Parts of the World, 1253–55",
        author: "William of Rubruck, translated by W. W. Rockhill (Hakluyt Society, 1900)",
        page: "pp. 176–177, 208, with the editor's notes",
        note:
            "Rubruck's own account of his journey to the court of Möngke Khan. Story text is an editorial retelling of the cited pages, not a quotation.",
        url: "https://archive.org/details/journeyofwilliam00ruys",
      ),
    ],
  ),
  StoryTemplate(
    id: "river-message",
    siteId: "kharkhorin",
    title: "A City of Four Gates",
    subtitle: "Karakorum through Rubruck's eyes · Chapter II",
    image: "assets/images/silver-tree.jpg",
    chapter: 2,
    genre: "Legend · domog",
    style: "Lyrical",
    mood: "Noble & brave",
    seed: "Walk the markets and temples of Karakorum in 1254.",
    segments: [
      StorySegment(
        kind: "legend",
        text:
            "Rubruck wrote that Karakorum was not even as big as the village of Saint-Denis outside Paris. It had two quarters: one of the Muslim merchants, where the markets were and where people gathered because of the court, and one of the Chinese craftsmen. Large buildings for the court's secretaries stood beside them.",
      ),
      StorySegment(
        kind: "legend",
        text:
            "He counted twelve temples of different peoples, two mosques and one Christian church at the far end of the city. A mud wall with four gates surrounded it. Millet and grain were sold at the east gate, sheep and goats at the west, oxen and carts at the south and horses at the north.",
      ),
      StorySegment(
        kind: "context",
        text:
            "Rubruck's description is one of very few eyewitness accounts of the Mongol capital.",
        citationId: "rubruck-1900-river-message",
      ),
    ],
    nextIds: ["steppe-return"],
    citations: [
      Citation(
        id: "rubruck-1900-river-message",
        title: "The Journey of William of Rubruck to the Eastern Parts of the World, 1253–55",
        author: "William of Rubruck, translated by W. W. Rockhill (Hakluyt Society, 1900)",
        page: "pp. 220–221",
        note:
            "Rubruck's own account of his journey to the court of Möngke Khan. Story text is an editorial retelling of the cited pages, not a quotation.",
        url: "https://archive.org/details/journeyofwilliam00ruys",
      ),
    ],
  ),
  StoryTemplate(
    id: "steppe-return",
    siteId: "kharkhorin",
    title: "The Khan's Letter",
    subtitle: "Leaving Karakorum, July 1254 · Chapter III",
    image: "assets/images/silver-tree.jpg",
    chapter: 3,
    genre: "Legend · domog",
    style: "Lyrical",
    mood: "Warm",
    seed: "Rubruck receives Möngke's letter and turns west.",
    segments: [
      StorySegment(
        kind: "legend",
        text:
            "Before Rubruck left, Möngke's secretaries prepared a letter for King Louis of France and read it to him through an interpreter. It opened with the Khan's claim of a heavenly mandate: in Heaven there is one eternal God, and on Earth one lord, Chinggis Khan. Rubruck wrote down its meaning as well as he could.",
      ),
      StorySegment(
        kind: "legend",
        text:
            "About two weeks after the feast of Saint John, around 8 July 1254, Rubruck took his leave. His sick companion stayed behind. Rubruck rode west through the desert to Batu's camp on the Volga, and from there continued south toward Syria.",
      ),
      StorySegment(
        kind: "context",
        text:
            "The letter survives only in Rubruck's summary. Its claim of universal rule matches other Mongol letters to European rulers.",
        citationId: "rubruck-1900-steppe-return",
      ),
    ],
    nextIds: [],
    citations: [
      Citation(
        id: "rubruck-1900-steppe-return",
        title: "The Journey of William of Rubruck to the Eastern Parts of the World, 1253–55",
        author: "William of Rubruck, translated by W. W. Rockhill (Hakluyt Society, 1900)",
        page: "pp. 247–252",
        note:
            "Rubruck's own account of his journey to the court of Möngke Khan. Story text is an editorial retelling of the cited pages, not a quotation.",
        url: "https://archive.org/details/journeyofwilliam00ruys",
      ),
    ],
  ),
  StoryTemplate(
    id: "kharkhorin-notebook",
    siteId: "kharkhorin",
    title: "A Debate at Karakorum",
    subtitle: "Pentecost eve, 1254",
    image: "assets/images/silver-tree.jpg",
    chapter: 1,
    genre: "Chronicle · tovchoo",
    style: "Plain modern",
    mood: "Quiet & reverent",
    seed: "The Khan orders a debate between Christians, Muslims and Buddhists.",
    segments: [
      StorySegment(
        kind: "legend",
        text:
            "On the eve of Pentecost in 1254, Möngke Khan had Christians, Muslims and Buddhists meet in Karakorum to debate their beliefs. He sent three secretaries as judges: a Christian, a Muslim and a Buddhist.",
      ),
      StorySegment(
        kind: "legend",
        text:
            "A crier announced the Khan's order: no one was to quarrel, insult another or make any noise that would disturb the debate, on pain of death. Everyone fell silent. Each side had brought its most learned people, and a large crowd gathered. The Christians placed Rubruck in the middle to speak for them.",
      ),
      StorySegment(
        kind: "context",
        text:
            "Rubruck records the debate from the Christian side. It shows how the Mongol court managed many religions at once.",
        citationId: "rubruck-1900-kharkhorin-notebook",
      ),
    ],
    nextIds: [],
    citations: [
      Citation(
        id: "rubruck-1900-kharkhorin-notebook",
        title: "The Journey of William of Rubruck to the Eastern Parts of the World, 1253–55",
        author: "William of Rubruck, translated by W. W. Rockhill (Hakluyt Society, 1900)",
        page: "pp. 229–230",
        note:
            "Rubruck's own account of his journey to the court of Möngke Khan. Story text is an editorial retelling of the cited pages, not a quotation.",
        url: "https://archive.org/details/journeyofwilliam00ruys",
      ),
    ],
  ),
  StoryTemplate(
    id: "erdene-bell",
    siteId: "erdene-zuu",
    title: "Stones from an Old Capital",
    subtitle: "The founding of Erdene Zuu, 1585",
    image: "assets/images/monastery.jpg",
    chapter: 1,
    genre: "Legend · domog",
    style: "Lyrical",
    mood: "Quiet & reverent",
    seed: "Abtai Sain Khan raises a monastery from Karakorum's ruins.",
    segments: [
      StorySegment(
        kind: "legend",
        text:
            "In 1585, Abtai Sain Khan of the Khalkha Mongols ordered a monastery built in the Orkhon Valley. He did this after meeting the Third Dalai Lama, when Tibetan Buddhism was declared the state religion. The monastery was named Erdene Zuu.",
      ),
      StorySegment(
        kind: "legend",
        text:
            "The builders took stones from the nearby ruins of Karakorum, the thirteenth-century Mongol capital. Its temple walls were painted, and the Chinese-style roofs were covered with green tiles. Abtai Sain Khan was the grandfather of Zanabazar, who later became Mongolia's first Jebtsundamba Khutuktu.",
      ),
      StorySegment(
        kind: "context",
        text:
            "Erdene Zuu is probably the earliest surviving Buddhist monastery in Mongolia and is part of the Orkhon Valley World Heritage Site.",
        citationId: "wiki-erdene-zuu-erdene-bell",
      ),
    ],
    nextIds: [],
    citations: [
      Citation(
        id: "wiki-erdene-zuu-erdene-bell",
        title: "Erdene Zuu Monastery",
        author: "Wikipedia",
        page: "History",
        note:
            "Founding in 1585, reuse of Karakorum stones, the 108-stupa wall, and the damage of 1688 and 1939.",
        url: "https://en.wikipedia.org/wiki/Erdene_Zuu_Monastery",
      ),
    ],
  ),
  StoryTemplate(
    id: "erdene-notebook",
    siteId: "erdene-zuu",
    title: "The Wall of 108 Stupas",
    subtitle: "Erdene Zuu across four centuries",
    image: "assets/images/monastery.jpg",
    chapter: 1,
    genre: "Chronicle · tovchoo",
    style: "Plain modern",
    mood: "Warm",
    seed: "Read the history written into the monastery's wall.",
    segments: [
      StorySegment(
        kind: "legend",
        text:
            "The builders planned a wall like a Buddhist rosary, with 108 stupas, because 108 is a sacred number in Buddhism. That goal was probably never fully achieved. In 1688, during the wars between the Dzungars and the Khalkha, the monastery was damaged and left empty for a time.",
      ),
      StorySegment(
        kind: "legend",
        text:
            "In 1939, during the communist purges, Choibalsan ordered the monastery destroyed. Three small temples and the outer wall with its stupas survived. In 1947 the temples became museums. After 1990 the monastery was returned to the lamas, and today it is both a working monastery and a museum.",
      ),
      StorySegment(
        kind: "context",
        text:
            "The surviving wall and temples are part of the Orkhon Valley Cultural Landscape.",
        citationId: "unesco-orkhon-erdene-notebook",
      ),
    ],
    nextIds: [],
    citations: [
      Citation(
        id: "unesco-orkhon-erdene-notebook",
        title: "Orkhon Valley Cultural Landscape",
        author: "UNESCO World Heritage Centre",
        page: "World Heritage List no. 1081",
        note:
            "The listed landscape includes Kharkhorum, Erdene Zuu and the Tövkhön hermitage.",
        url: "https://whc.unesco.org/en/list/1081/",
      ),
    ],
  ),
  StoryTemplate(
    id: "tovkhon-path",
    siteId: "tovkhon",
    title: "Zanabazar's Hermitage",
    subtitle: "Tövkhön, founded 1648",
    image: "assets/images/landscape.jpg",
    chapter: 1,
    genre: "Legend · domog",
    style: "Lyrical",
    mood: "Mysterious",
    seed: "A fourteen-year-old spiritual leader chooses a mountain retreat.",
    segments: [
      StorySegment(
        kind: "legend",
        text:
            "In 1648, the fourteen-year-old Zanabazar, spiritual leader of the Khalkha Mongols, chose a place on Shireet Ulaan Uul, high on a forested ridge, as an auspicious site. He named it Bayasgalant Aglag Oron, the Happy Secluded Place.",
      ),
      StorySegment(
        kind: "legend",
        text:
            "The first buildings went up after he returned from studying in Tibet in 1653. For about thirty years Tövkhön was his personal retreat. There Zanabazar, a sculptor, painter and musician, made many of his best-known works.",
      ),
      StorySegment(
        kind: "context",
        text:
            "Tövkhön lies about 47 km southwest of Kharkhorin and is part of the Orkhon Valley World Heritage Site.",
        citationId: "wiki-tovkhon-tovkhon-path",
      ),
    ],
    nextIds: [],
    citations: [
      Citation(
        id: "wiki-tovkhon-tovkhon-path",
        title: "Tövkhön Monastery",
        author: "Wikipedia",
        page: "History",
        note:
            "Founding by Zanabazar in 1648, building from 1653, destruction in 1688, restoration in 1773 and 1997.",
        url: "https://en.wikipedia.org/wiki/T%C3%B6vkh%C3%B6n_Monastery",
      ),
    ],
  ),
  StoryTemplate(
    id: "tovkhon-notebook",
    siteId: "tovkhon",
    title: "Where the Soyombo Was Shaped",
    subtitle: "Zanabazar's workshop, 1680s",
    image: "assets/images/landscape.jpg",
    chapter: 1,
    genre: "Chronicle · tovchoo",
    style: "Plain modern",
    mood: "Quiet & reverent",
    seed: "Art, script and survival at Tövkhön.",
    segments: [
      StorySegment(
        kind: "legend",
        text:
            "In the 1670s and 1680s, Zanabazar and his apprentices at Tövkhön made hundreds of works for the monasteries he founded. His masterworks from the mid-1680s include the White Tara and Vajradhara. In 1686 he designed the Soyombo script to help translate between Mongolian, Tibetan and Sanskrit. Its emblem later became a national symbol of Mongolia.",
      ),
      StorySegment(
        kind: "legend",
        text:
            "In 1688, Oirat forces destroyed the hermitage during their war against the Khalkha. It was restored in 1773 and badly damaged again in the purges of the late 1930s. Religious life returned in 1992, and restoration finished in 1997.",
      ),
      StorySegment(
        kind: "context",
        text:
            "Two original temples and two stupas from the 17th century still stand at Tövkhön.",
        citationId: "wiki-tovkhon-tovkhon-notebook",
      ),
    ],
    nextIds: [],
    citations: [
      Citation(
        id: "wiki-tovkhon-tovkhon-notebook",
        title: "Tövkhön Monastery",
        author: "Wikipedia",
        page: "History",
        note:
            "Founding by Zanabazar in 1648, building from 1653, destruction in 1688, restoration in 1773 and 1997.",
        url: "https://en.wikipedia.org/wiki/T%C3%B6vkh%C3%B6n_Monastery",
      ),
    ],
  ),
  StoryTemplate(
    id: "waterfall-ribbon",
    siteId: "ulaan-tsutgalan",
    title: "Born of Lava",
    subtitle: "How Ulaan Tsutgalan formed",
    image: "assets/images/steppe.jpg",
    chapter: 1,
    genre: "Legend · domog",
    style: "Lyrical",
    mood: "Noble & brave",
    seed: "A volcanic eruption and a river carve Mongolia's widest waterfall.",
    segments: [
      StorySegment(
        kind: "legend",
        text:
            "In the Quaternary period, a volcano erupted near the source of the Tsagaan Azarga River. Lava flowed down the Orkhon Valley and left thick layers of volcanic rock stretching for several kilometers.",
      ),
      StorySegment(
        kind: "legend",
        text:
            "Over time the Orkhon River cut through these layers and made the gorge where the water now falls. The Ulaan Tsutgalan waterfall is about 24 meters high and 10 meters wide, the widest in Mongolia. Its water comes from the Orkhon River.",
      ),
      StorySegment(
        kind: "context",
        text:
            "The waterfall lies in Bat-Ölzii District, Övörkhangai Province, upstream of Kharkhorin.",
        citationId: "wiki-ulaan-tsutgalan-waterfall-ribbon",
      ),
    ],
    nextIds: [],
    citations: [
      Citation(
        id: "wiki-ulaan-tsutgalan-waterfall-ribbon",
        title: "Ulaan Tsutgalan Waterfall",
        author: "Wikipedia",
        page: "History · Geology",
        note:
            "Quaternary lava from the Tsagaan Azarga source; the falls are about 24 m high and 10 m wide.",
        url: "https://en.wikipedia.org/wiki/Orkhon_Waterfall",
      ),
    ],
  ),
  StoryTemplate(
    id: "waterfall-notebook",
    siteId: "ulaan-tsutgalan",
    title: "The River of Capitals",
    subtitle: "The Orkhon Valley over two thousand years",
    image: "assets/images/steppe.jpg",
    chapter: 1,
    genre: "Chronicle · tovchoo",
    style: "Plain modern",
    mood: "Warm",
    seed: "Follow the Orkhon from the waterfall past three empires.",
    segments: [
      StorySegment(
        kind: "legend",
        text:
            "The water that falls at Ulaan Tsutgalan flows on through a valley that served for centuries as a seat of steppe empires. In the eighth century, the Göktürk ruler Bilge Khan set up stone stelae here, carved in the Old Turkic script. The Orkhon inscriptions were rediscovered in 1889.",
      ),
      StorySegment(
        kind: "legend",
        text:
            "Later the Uyghurs built their capital, Ordu-Baliq, in the same valley, and in the thirteenth century the Mongols built Karakorum. UNESCO inscribed the valley in 2004 for nomadic pastoral traditions spanning more than two thousand years.",
      ),
      StorySegment(
        kind: "context",
        text:
            "The Orkhon Valley Cultural Landscape was inscribed on the World Heritage List in 2004.",
        citationId: "unesco-orkhon-waterfall-notebook",
      ),
    ],
    nextIds: [],
    citations: [
      Citation(
        id: "unesco-orkhon-waterfall-notebook",
        title: "Orkhon Valley Cultural Landscape",
        author: "UNESCO World Heritage Centre",
        page: "World Heritage List no. 1081",
        note:
            "The listed landscape includes Kharkhorum, Erdene Zuu and the Tövkhön hermitage.",
        url: "https://whc.unesco.org/en/list/1081/",
      ),
    ],
  ),
];
