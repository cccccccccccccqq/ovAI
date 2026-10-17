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
        "An ancient capital in the living Orkhon Valley. Follow an imagined envoy through its gates.",
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
        "A Buddhist monastery in the Orkhon cultural landscape. Discover a quiet, imagined morning.",
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
        "A mountain hermitage. Walk a prepared story of patience, craft and the forest.",
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
        "A waterfall landscape in the Orkhon Valley. Listen to an imagined journey beside the water.",
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
    id: "unesco-capital",
    title: "Orkhon Valley Cultural Landscape",
    author: "UNESCO World Heritage Centre",
    page: "Description · cultural landscape",
    note:
        "Background reading for the setting. The envoy, dialogue and events are original demo fiction.",
    url: "https://whc.unesco.org/en/list/1081/",
  ),
  Citation(
    id: "unesco-monasteries",
    title: "Orkhon Valley Cultural Landscape",
    author: "UNESCO World Heritage Centre",
    page: "Outstanding Universal Value · Buddhist heritage",
    note:
        "Background reading about Erdene Zuu and Tövkhön. Story characters and scenes are fictional.",
    url: "https://whc.unesco.org/en/list/1081/",
  ),
  Citation(
    id: "demo-editorial",
    title: "ÖV prototype editorial note",
    author: "Prepared demo collection",
    page: "Content version · October 2026",
    note:
        "Original writing for interaction testing. It is not a traditional legend, a historical quotation or a verified account.",
    url: null,
  ),
];

/// Original editorial fiction; "context" blocks link to reading notes.
/// Each selectable preset has different text and matching narration assets.
const demoTemplates = <StoryTemplate>[
  StoryTemplate(
    id: "silver-tree",
    siteId: "kharkhorin",
    title: "Beneath the Silver Tree",
    subtitle: "The envoy arrives · Chapter I",
    image: "assets/images/silver-tree.jpg",
    chapter: 1,
    genre: "Legend · domog",
    style: "Lyrical",
    mood: "Noble & brave",
    seed: "An envoy reaches the gates as the court gathers.",
    segments: [
      StorySegment(
        kind: "legend",
        text:
            "The envoy stopped where the road met the city gate. Dust lay on his cloak, and the morning wind carried the voices of people whose words he did not yet know. He loosened his grip on the letter in his sleeve.",
      ),
      StorySegment(
        kind: "legend",
        text:
            "Beyond the wall, a silver tree seemed to gather the light. A young apprentice led him toward it. Every road brings a different question, she said. The envoy looked back at the open steppe and wondered which question he had carried all this way.",
      ),
      StorySegment(
        kind: "context",
        text:
            "Kharkhorum is part of the UNESCO-listed Orkhon Valley cultural landscape.",
        citationId: "unesco-capital",
      ),
    ],
    nextIds: ["workshop", "river-message"],
  ),
  StoryTemplate(
    id: "workshop",
    siteId: "kharkhorin",
    title: "The Goldsmith’s Lantern",
    subtitle: "Follow the apprentice · Chapter II",
    image: "assets/images/silver-tree.jpg",
    chapter: 2,
    genre: "Legend · domog",
    style: "Lyrical",
    mood: "Mysterious",
    seed: "A lantern reveals the patient work behind the silver tree.",
    segments: [
      StorySegment(
        kind: "legend",
        text:
            "The apprentice pushed open a workshop door. Under a small lantern, bowls, tools and unfinished shapes waited on a wooden bench. The envoy had expected a room of treasure. Instead, he found a room of patient hands.",
      ),
      StorySegment(
        kind: "legend",
        text:
            "She lifted a thin curl of metal and held it against the light. A tree begins with something small, she said. Outside, the city hurried toward evening. The envoy sat down and, for the first time in many days, let the letter rest.",
      ),
      StorySegment(
        kind: "context",
        text:
            "This workshop scene is original fiction created for the prototype.",
        citationId: "demo-editorial",
      ),
    ],
    nextIds: ["steppe-return"],
  ),
  StoryTemplate(
    id: "river-message",
    siteId: "kharkhorin",
    title: "A Message at Dusk",
    subtitle: "Follow the rider · Chapter II",
    image: "assets/images/silver-tree.jpg",
    chapter: 2,
    genre: "Legend · domog",
    style: "Lyrical",
    mood: "Noble & brave",
    seed: "A rider asks the envoy to follow the river at dusk.",
    segments: [
      StorySegment(
        kind: "legend",
        text:
            "At the western gate, a rider was tightening a saddle strap. The river is still bright, she told the envoy. Walk with me until the last bend. He followed, carrying the sealed letter and a question he had not asked inside the city.",
      ),
      StorySegment(
        kind: "legend",
        text:
            "The river turned copper in the evening. Neither spoke for a while. Then the rider pointed toward the hills. A message matters, she said, but so does the person who brings it home. The envoy watched the current carry the light away.",
      ),
      StorySegment(
        kind: "context",
        text:
            "The rider and message are fictional elements of this branching demo.",
        citationId: "demo-editorial",
      ),
    ],
    nextIds: ["steppe-return"],
  ),
  StoryTemplate(
    id: "steppe-return",
    siteId: "kharkhorin",
    title: "The Road Remembers",
    subtitle: "Return to the open steppe · Chapter III",
    image: "assets/images/silver-tree.jpg",
    chapter: 3,
    genre: "Legend · domog",
    style: "Lyrical",
    mood: "Warm",
    seed: "The envoy leaves with a different understanding of the journey.",
    segments: [
      StorySegment(
        kind: "legend",
        text:
            "At sunrise the envoy left the city. Behind him, the gate grew smaller; ahead, the steppe opened without a line to mark its edge. He still carried a letter, but now he remembered the apprentice’s hands and the rider’s unhurried voice.",
      ),
      StorySegment(
        kind: "legend",
        text:
            "He stopped once beside the river. A bird crossed the sky, and the wind moved through the grass in a long, soft wave. He had come looking for a story worthy of a capital. He went home carrying stories small enough to share around a fire.",
      ),
      StorySegment(
        kind: "context",
        text: "This ending completes one prepared three-chapter demo journey.",
        citationId: "demo-editorial",
      ),
    ],
    nextIds: [],
  ),
  StoryTemplate(
    id: "kharkhorin-notebook",
    siteId: "kharkhorin",
    title: "Notes from the Valley",
    subtitle: "A present-day travel notebook",
    image: "assets/images/silver-tree.jpg",
    chapter: 1,
    genre: "Chronicle · tovchoo",
    style: "Plain modern",
    mood: "Quiet & reverent",
    seed: "A visitor records what is present and what must be imagined.",
    segments: [
      StorySegment(
        kind: "legend",
        text:
            "I opened my notebook before writing a date. The first thing to record was the wind. It moved across the grass and pressed the page against my hand. Around me, a living town continued its ordinary morning.",
      ),
      StorySegment(
        kind: "legend",
        text:
            "I drew two columns: what I could see, and what I could only imagine. The second filled faster. Before leaving, I circled the first column. A careful journey begins by knowing the difference.",
      ),
      StorySegment(
        kind: "context",
        text:
            "The valley connects pastoral life with historic administrative and religious centres.",
        citationId: "unesco-capital",
      ),
    ],
    nextIds: [],
  ),
  StoryTemplate(
    id: "erdene-bell",
    siteId: "erdene-zuu",
    title: "Before the Morning Bell",
    subtitle: "A quiet monastery story",
    image: "assets/images/monastery.jpg",
    chapter: 1,
    genre: "Legend · domog",
    style: "Lyrical",
    mood: "Quiet & reverent",
    seed: "A visitor learns to wait in the monastery courtyard.",
    segments: [
      StorySegment(
        kind: "legend",
        text:
            "The courtyard was quiet when the traveller arrived. A caretaker swept the path slowly, leaving a clear line through yesterday’s dust. The traveller asked where the story began. The caretaker handed him a second broom.",
      ),
      StorySegment(
        kind: "legend",
        text:
            "They worked without speaking. By the time sunlight reached the doorway, the traveller had forgotten the question he meant to ask. He listened to the sound of the bristles against stone. Some mornings, he decided, were already enough.",
      ),
      StorySegment(
        kind: "context",
        text: "Erdene Zuu belongs to the valley’s Buddhist cultural heritage.",
        citationId: "unesco-monasteries",
      ),
    ],
    nextIds: [],
  ),
  StoryTemplate(
    id: "erdene-notebook",
    siteId: "erdene-zuu",
    title: "A Courtyard Notebook",
    subtitle: "Observation before imagination",
    image: "assets/images/monastery.jpg",
    chapter: 1,
    genre: "Chronicle · tovchoo",
    style: "Plain modern",
    mood: "Warm",
    seed: "A visitor notices the small details around a courtyard.",
    segments: [
      StorySegment(
        kind: "legend",
        text:
            "My first note was a sketch of a doorway. The second was the shape of a shadow. I had arrived with a list of things to learn, but the courtyard asked me to slow down before naming anything.",
      ),
      StorySegment(
        kind: "legend",
        text:
            "I wrote that this was a visit, not a claim to understand every symbol. Some questions would need a guide and more reading. For today, I could offer attention, a quiet voice and a careful step.",
      ),
      StorySegment(
        kind: "context",
        text:
            "The visitor and notebook are fictional; the setting is cultural heritage.",
        citationId: "demo-editorial",
      ),
    ],
    nextIds: [],
  ),
  StoryTemplate(
    id: "tovkhon-path",
    siteId: "tovkhon",
    title: "The Patient Path",
    subtitle: "A forest ascent",
    image: "assets/images/landscape.jpg",
    chapter: 1,
    genre: "Legend · domog",
    style: "Lyrical",
    mood: "Mysterious",
    seed: "A traveller follows a mountain path one breath at a time.",
    segments: [
      StorySegment(
        kind: "legend",
        text:
            "The path climbed between the trees and disappeared around another bend. The traveller counted the things still to do until a fallen pine needle landed on her sleeve. She stopped counting and looked up.",
      ),
      StorySegment(
        kind: "legend",
        text:
            "Light moved over the bark. Somewhere ahead, another walker paused too. When they reached the clearing, neither asked who had arrived first. They sat together and watched the forest fill the space they had left for words.",
      ),
      StorySegment(
        kind: "context",
        text:
            "Tövkhön Hermitage is included in the Orkhon Valley cultural landscape.",
        citationId: "unesco-monasteries",
      ),
    ],
    nextIds: [],
  ),
  StoryTemplate(
    id: "tovkhon-notebook",
    siteId: "tovkhon",
    title: "A Clearing Above the Trees",
    subtitle: "A mountain notebook",
    image: "assets/images/landscape.jpg",
    chapter: 1,
    genre: "Chronicle · tovchoo",
    style: "Plain modern",
    mood: "Quiet & reverent",
    seed: "A walker records the changing sounds of an ascent.",
    segments: [
      StorySegment(
        kind: "legend",
        text:
            "At the start of the walk I wrote about distance. Higher up I wrote about breath. In the clearing I stopped measuring altogether. The notebook lay open while the trees moved in a wind I could hear before I felt it.",
      ),
      StorySegment(
        kind: "legend",
        text:
            "On the way down, the same bends looked different. I added one final line: a path is more than its destination. It is also the attention we bring back with us.",
      ),
      StorySegment(
        kind: "context",
        text: "This reflective walk is prepared fiction, not visitor guidance.",
        citationId: "demo-editorial",
      ),
    ],
    nextIds: [],
  ),
  StoryTemplate(
    id: "waterfall-ribbon",
    siteId: "ulaan-tsutgalan",
    title: "The River’s Ribbon",
    subtitle: "A story beside the water",
    image: "assets/images/steppe.jpg",
    chapter: 1,
    genre: "Legend · domog",
    style: "Lyrical",
    mood: "Noble & brave",
    seed: "A child asks where a river keeps its stories.",
    segments: [
      StorySegment(
        kind: "legend",
        text:
            "The child asked where the river kept its stories. Her grandfather pointed first upstream, then downstream, and finally to the place where they stood. She frowned. That is three answers, she said. He smiled and handed her a smooth stone.",
      ),
      StorySegment(
        kind: "legend",
        text:
            "They listened beside the water. The stone warmed in her palm. By the time they turned toward home, she had found a fourth answer: perhaps a river leaves a little of its story with everyone who stops to listen.",
      ),
      StorySegment(
        kind: "context",
        text:
            "This is an original fictional tale, not a recorded local tradition.",
        citationId: "demo-editorial",
      ),
    ],
    nextIds: [],
  ),
  StoryTemplate(
    id: "waterfall-notebook",
    siteId: "ulaan-tsutgalan",
    title: "Listening to Water",
    subtitle: "A valley notebook",
    image: "assets/images/steppe.jpg",
    chapter: 1,
    genre: "Chronicle · tovchoo",
    style: "Plain modern",
    mood: "Warm",
    seed: "A visitor puts the camera away and listens.",
    segments: [
      StorySegment(
        kind: "legend",
        text:
            "I took one photograph and then put the camera away. For a moment I did not try to turn the water into an image. I listened to its changing sound and watched a ribbon of mist drift across the view.",
      ),
      StorySegment(
        kind: "legend",
        text:
            "Later, the photograph would help me remember where I had stood. The notebook would help me remember how it felt to stay there. I left the page unfinished, with room for a return.",
      ),
      StorySegment(
        kind: "context",
        text:
            "The scene is an editorial demo, not an account of current trail conditions.",
        citationId: "demo-editorial",
      ),
    ],
    nextIds: [],
  ),
];
