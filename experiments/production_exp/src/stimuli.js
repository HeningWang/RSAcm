// production_exp/src/stimuli.js
//
// AUTO-GENERATED from items.csv — do not edit manually.
// Run: python experiments/item/generate_stimuli.py
//
// Latin square design: 8 critical items x 4 conditions, 4 lists.
// Each participant sees 8 critical trials (one per item, one per condition)
// plus 8 fillers, shuffled -> 16 trials total.
//
// List assignment: getCriticalTrials(listNum) implements the rotation.
// In list l, item i gets condition (i + l) % 4.
//
// Conditions are encoded as a 2-bit index:
//   bit 1 = pc_prag  (0 = low, 1 = high)
//   bit 0 = g        (0 = low, 1 = high)
//
//   0 = low  / low
//   1 = low  / high
//   2 = high / low
//   3 = high / high
//
// pc_prop is no longer a within-experiment manipulation.
// A continuous pc_prop_rating (0-100) for each topic is obtained from the
// separate norming study and used as a continuous predictor in analysis.
//
// Each critical item carries 2 context strings indexed by pc_prag:
//   [0] pc_prag: low   (social circle mostly shares the view)
//   [1] pc_prag: high  (social circle opinions diverge)
// The contextIndex = conditionIndex >> 1 (strips the g bit).

const GOAL_LOW  = 'Du möchtest einen Vorschlag machen und diesen nur kurz anmerken.';
const GOAL_HIGH = 'Du möchtest einen Vorschlag machen. Es ist dir sehr wichtig, dass dein/e Gesprächspartner/in diesen Vorschlag akzeptiert.';

const CONDITIONS = [
  { pc_prag: 'low',  g: 'low',  goalInstruction: GOAL_LOW  }, // 0
  { pc_prag: 'low',  g: 'high', goalInstruction: GOAL_HIGH }, // 1
  { pc_prag: 'high', g: 'low',  goalInstruction: GOAL_LOW  }, // 2
  { pc_prag: 'high', g: 'high', goalInstruction: GOAL_HIGH }, // 3
];

// ── Critical items (IDs 1-8) ─────────────────────────────────────────────────
// contexts[]: [pc_prag low, pc_prag high]

const CRITICAL_ITEMS = [
  // ── Item 1: Klimawandel ─────────────────────────────────────────────────
  {
    id: 1,
    topic: 'klimawandel',
    sentenceBefore: 'Der Klimawandel wird',
    sentenceAfter:  'durch menschliche Aktivitäten verursacht.',
    q: 'auf Flugreisen verzichten',
    contexts: [
      'Du sprichst mit einem/einer Gesprächspartner/in über den Klimawandel. In eurem gemeinsamen Umfeld teilen die meisten die Ansicht, dass der Klimawandel durch menschliche Aktivitäten verursacht wird.',

      'Du sprichst mit einem/einer Gesprächspartner/in über den Klimawandel. In eurem gemeinsamen Umfeld gehen die Meinungen dazu allerdings stark auseinander.',
    ],
  },

  // ── Item 2: Ernaehrung ──────────────────────────────────────────────────
  {
    id: 2,
    topic: 'ernaehrung',
    sentenceBefore: 'Eine überwiegend pflanzliche Ernährung fördert',
    sentenceAfter:  'die Gesundheit.',
    q: 'mehr pflanzliche Lebensmittel in deinen Alltag einbauen',
    contexts: [
      'Du sprichst mit einem/einer Gesprächspartner/in über Ernährungsgewohnheiten. In eurem gemeinsamen Umfeld teilen die meisten die Überzeugung, dass eine überwiegend pflanzliche Ernährung die Gesundheit fördert.',

      'Du sprichst mit einem/einer Gesprächspartner/in über Ernährungsgewohnheiten. In eurem gemeinsamen Umfeld herrschen dazu sehr unterschiedliche Meinungen.',
    ],
  },

  // ── Item 3: Stadtverkehr ────────────────────────────────────────────────
  {
    id: 3,
    topic: 'stadtverkehr',
    sentenceBefore: 'Ein ausgebautes Nahverkehrsnetz entlastet',
    sentenceAfter:  'den Stadtverkehr erheblich.',
    q: 'häufiger auf öffentliche Verkehrsmittel umsteigen',
    contexts: [
      'Du sprichst mit einem/einer Gesprächspartner/in über Verkehrspolitik in eurer Stadt. In eurem gemeinsamen Umfeld sehen das die meisten ähnlich, dass ein ausgebautes Nahverkehrsnetz den Stadtverkehr deutlich entlastet.',

      'Du sprichst mit einem/einer Gesprächspartner/in über Verkehrspolitik in eurer Stadt. In eurem gemeinsamen Umfeld gehen die Meinungen dazu weit auseinander.',
    ],
  },

  // ── Item 4: Digitalisierung ─────────────────────────────────────────────
  {
    id: 4,
    topic: 'digitalisierung',
    sentenceBefore: 'Digitale Kompetenzen sind',
    sentenceAfter:  'in der heutigen Arbeitswelt unverzichtbar.',
    q: 'regelmäßig digitale Weiterbildungsangebote nutzen',
    contexts: [
      'Du sprichst mit einem/einer Gesprächspartner/in über Berufsausbildung und Weiterbildung. In eurem gemeinsamen Umfeld teilen die meisten die Ansicht, dass digitale Kompetenzen in der heutigen Arbeitswelt unverzichtbar sind.',

      'Du sprichst mit einem/einer Gesprächspartner/in über Berufsausbildung und Weiterbildung. In eurem gemeinsamen Umfeld gehen die Meinungen dazu stark auseinander.',
    ],
  },

  // ── Item 5: Schlaf ──────────────────────────────────────────────────────
  {
    id: 5,
    topic: 'schlaf',
    sentenceBefore: 'Ausreichend Schlaf ist',
    sentenceAfter:  'entscheidend für die kognitive Leistungsfähigkeit.',
    q: 'auf feste Schlafzeiten achten',
    contexts: [
      'Du sprichst mit einem/einer Gesprächspartner/in über Gesundheit und Wohlbefinden. In eurem gemeinsamen Umfeld teilen die meisten die Ansicht, dass ausreichend Schlaf entscheidend für die kognitive Leistungsfähigkeit ist.',

      'Du sprichst mit einem/einer Gesprächspartner/in über Gesundheit und Wohlbefinden. In eurem gemeinsamen Umfeld gehen die Meinungen dazu stark auseinander.',
    ],
  },

  // ── Item 6: Plastik ─────────────────────────────────────────────────────
  {
    id: 6,
    topic: 'plastik',
    sentenceBefore: 'Einwegplastik schadet',
    sentenceAfter:  'den Meeresökosystemen erheblich.',
    q: 'konsequent auf Einwegplastik verzichten',
    contexts: [
      'Du sprichst mit einem/einer Gesprächspartner/in über Umweltschutz. In eurem gemeinsamen Umfeld teilen die meisten die Überzeugung, dass Einwegplastik den Meeresökosystemen erheblich schadet.',

      'Du sprichst mit einem/einer Gesprächspartner/in über Umweltschutz. In eurem gemeinsamen Umfeld herrschen dazu sehr unterschiedliche Meinungen.',
    ],
  },

  // ── Item 7: Sport ───────────────────────────────────────────────────────
  {
    id: 7,
    topic: 'sport',
    sentenceBefore: 'Regelmäßige körperliche Bewegung senkt',
    sentenceAfter:  'das Risiko für Herz-Kreislauf-Erkrankungen deutlich.',
    q: 'regelmäßig Sport in deinen Alltag integrieren',
    contexts: [
      'Du sprichst mit einem/einer Gesprächspartner/in über gesunden Lebensstil. In eurem gemeinsamen Umfeld teilen die meisten die Ansicht, dass regelmäßige körperliche Bewegung das Risiko für Herz-Kreislauf-Erkrankungen deutlich senkt.',

      'Du sprichst mit einem/einer Gesprächspartner/in über gesunden Lebensstil. In eurem gemeinsamen Umfeld gehen die Meinungen dazu stark auseinander.',
    ],
  },

  // ── Item 8: Lokalkauf ───────────────────────────────────────────────────
  {
    id: 8,
    topic: 'lokalkauf',
    sentenceBefore: 'Das Kaufen bei lokalen Händlern stärkt',
    sentenceAfter:  'die regionale Wirtschaft nachhaltig.',
    q: 'öfter bei lokalen Geschäften einkaufen',
    contexts: [
      'Du sprichst mit einem/einer Gesprächspartner/in über Einkaufsgewohnheiten. In eurem gemeinsamen Umfeld teilen die meisten die Überzeugung, dass das Kaufen bei lokalen Händlern die regionale Wirtschaft nachhaltig stärkt.',

      'Du sprichst mit einem/einer Gesprächspartner/in über Einkaufsgewohnheiten. In eurem gemeinsamen Umfeld gehen die Meinungen dazu weit auseinander.',
    ],
  },

];

// ── Latin square rotation ────────────────────────────────────────────────────
// Returns 8 trial objects for the given list number (0-3).
// Item i is shown in condition (i + listNum) % 4.
export function getCriticalTrials(listNum) {
  return CRITICAL_ITEMS.map((item, i) => {
    const conditionIndex = (i + listNum) % 4;
    const cond = CONDITIONS[conditionIndex];
    // contextIndex = pc_prag bit = conditionIndex >> 1
    //   0,1 -> 0 (pc_prag low)   2,3 -> 1 (pc_prag high)
    const contextIndex = conditionIndex >> 1;
    return {
      id: item.id,
      topic: item.topic,
      is_filler: false,
      pc_prag: cond.pc_prag,
      g: cond.g,
      condition_index: conditionIndex,
      context: item.contexts[contextIndex],
      goalInstruction: cond.goalInstruction,
      sentenceBefore: item.sentenceBefore,
      sentenceAfter: item.sentenceAfter,
      q: item.q,
    };
  });
}

// ── Filler items (IDs 101-108) ───────────────────────────────────────────────
// Fixed context, no condition variation.
// All q values are bare infinitives (no "zu") — matches "solltest du ___".
export const FILLERS = [
  {
    id: 101,
    topic: 'bahn',
    is_filler: true,
    pc_prag: null, g: null, condition_index: null,
    context:
      'Du sprichst mit einem/einer Gesprächspartner/in über Reisemöglichkeiten in Deutschland. Ihr überlegt, wie man umweltfreundlich von München nach Hamburg kommen kann.',
    goalInstruction: GOAL_LOW,
    sentenceBefore: 'Der Zug ist',
    sentenceAfter:  'für Reisen innerhalb Deutschlands sehr praktisch.',
    q: 'häufiger mit der Bahn reisen',
  },
  {
    id: 102,
    topic: 'leselicht',
    is_filler: true,
    pc_prag: null, g: null, condition_index: null,
    context:
      'Du sprichst mit einem/einer Gesprächspartner/in, die sich über Kopfschmerzen beim Lesen beklagt. Ihr sitzt abends zusammen am Küchentisch.',
    goalInstruction: GOAL_HIGH,
    sentenceBefore: 'Gutes Licht beim Lesen schont',
    sentenceAfter:  'die Augen.',
    q: 'dir eine bessere Leselampe anschaffen',
  },
  {
    id: 103,
    topic: 'kochen',
    is_filler: true,
    pc_prag: null, g: null, condition_index: null,
    context:
      'Du sprichst mit einem/einer Gesprächspartner/in über den Ernährungsalltag. Dein Gegenüber klagt, dass das Geld für Essen kaum reicht.',
    goalInstruction: GOAL_LOW,
    sentenceBefore: 'Frisch kochen spart',
    sentenceAfter:  'auf Dauer Geld im Vergleich zu Fertiggerichten.',
    q: 'öfter selbst kochen',
  },
  {
    id: 104,
    topic: 'kaffee',
    is_filler: true,
    pc_prag: null, g: null, condition_index: null,
    context:
      'Du sprichst mit einem/einer Gesprächspartner/in, die morgens immer sehr müde ist. Ihr trefft euch an der Kaffeemaschine im Büro.',
    goalInstruction: GOAL_HIGH,
    sentenceBefore: 'Ein Kaffee am Morgen hilft',
    sentenceAfter:  'vielen Menschen, wach zu werden.',
    q: 'morgens eine kleine Kaffeepause einplanen',
  },
  {
    id: 105,
    topic: 'urlaub',
    is_filler: true,
    pc_prag: null, g: null, condition_index: null,
    context:
      'Du sprichst mit einem/einer Gesprächspartner/in, die seit Monaten ohne Urlaub durcharbeitet und erschöpft wirkt. Ihr sitzt zusammen beim Mittagessen.',
    goalInstruction: GOAL_LOW,
    sentenceBefore: 'Regelmäßige Auszeiten tun',
    sentenceAfter:  'der mentalen Gesundheit gut.',
    q: 'dieses Jahr endlich Urlaub nehmen',
  },
  {
    id: 106,
    topic: 'trinken',
    is_filler: true,
    pc_prag: null, g: null, condition_index: null,
    context:
      'Du sprichst mit einem/einer Gesprächspartner/in, die sich nachmittags immer schlapp und unkonzentriert fühlt. Ihr seid zu Hause in der Küche.',
    goalInstruction: GOAL_HIGH,
    sentenceBefore: 'Genügend Wasser zu trinken verbessert',
    sentenceAfter:  'die Konzentrationsfähigkeit.',
    q: 'öfter ein Glas Wasser trinken',
  },
  {
    id: 107,
    topic: 'frischluft',
    is_filler: true,
    pc_prag: null, g: null, condition_index: null,
    context:
      'Du sprichst mit einem/einer Gesprächspartner/in, die sich in eurem schlecht belüfteten Großraumbüro häufig unwohl fühlt. Es ist Mittag und alle sitzen eng beisammen.',
    goalInstruction: GOAL_LOW,
    sentenceBefore: 'Regelmäßiges Lüften verbessert',
    sentenceAfter:  'die Raumluftqualität merklich.',
    q: 'dein Büro öfter lüften',
  },
  {
    id: 108,
    topic: 'laerm',
    is_filler: true,
    pc_prag: null, g: null, condition_index: null,
    context:
      'Du sprichst mit einem/einer Gesprächspartner/in, die ständig mit voller Lautstärke Musik über Kopfhörer hört. Ihr seid gerade zusammen in der S-Bahn.',
    goalInstruction: GOAL_HIGH,
    sentenceBefore: 'Laute Musik in Kopfhörern schädigt',
    sentenceAfter:  'auf Dauer das Gehör.',
    q: 'die Lautstärke beim Musikhören reduzieren',
  },
];
