// comprehension_exp/src/stimuli.js
//
// Latin square design: 8 critical items × 4 conditions, 4 lists.
// Each participant sees 8 critical trials (one per item) plus 8 fillers → 16 trials.
//
// List assignment: getCriticalTrials(listNum) implements the rotation.
// In list l, item i gets condition (i + l) % 4.
//
// Conditions are encoded as a 2-bit index:
//   bit 1 = pc_prag  (0 = low, 1 = high)
//   bit 0 = g_implied (0 = low, 1 = high)
//
//   0 = low  / low
//   1 = low  / high
//   2 = high / low
//   3 = high / high
//
// IMPORTANT: Unlike production, the marker is NOT chosen by the participant.
// It is pre-assigned based on the fitted production model (modal marker for
// each item × condition cell). The MARKER_ASSIGNMENT matrix below is a
// placeholder and MUST be updated after the production model is fitted.
//
// Listener perspective: contexts describe overhearing a colleague speak,
// rather than being the speaker oneself.

const CONDITIONS = [
  { pc_prag: 'low',  g_implied: 'low'  }, // 0
  { pc_prag: 'low',  g_implied: 'high' }, // 1
  { pc_prag: 'high', g_implied: 'low'  }, // 2
  { pc_prag: 'high', g_implied: 'high' }, // 3
];

// ── Marker assignment matrix (8 items × 4 conditions) ──────────────────────
// PLACEHOLDER: Replace with production model results before data collection.
// Each entry is one of: 'soviel ich weiß', 'ja', 'bekanntlich'
//
// markerAssignment[itemIndex][conditionIndex] → marker string
//
// Current values are illustrative defaults based on theoretical predictions:
//   low pc_prag + low g  → 'soviel ich weiß' (weakest)
//   low pc_prag + high g → 'bekanntlich' (strongest)
//   high pc_prag + low g → 'soviel ich weiß' (weakest)
//   high pc_prag + high g → 'ja' (middle; attenuated by controversy)
const MARKER_ASSIGNMENT = [
  // Item 1–8, conditions 0–3
  ['soviel ich weiß', 'bekanntlich', 'soviel ich weiß', 'ja'], // 1: klimawandel
  ['soviel ich weiß', 'bekanntlich', 'soviel ich weiß', 'ja'], // 2: ernaehrung
  ['soviel ich weiß', 'bekanntlich', 'soviel ich weiß', 'ja'], // 3: stadtverkehr
  ['soviel ich weiß', 'bekanntlich', 'soviel ich weiß', 'ja'], // 4: digitalisierung
  ['soviel ich weiß', 'bekanntlich', 'soviel ich weiß', 'ja'], // 5: schlaf
  ['soviel ich weiß', 'bekanntlich', 'soviel ich weiß', 'ja'], // 6: plastik
  ['soviel ich weiß', 'bekanntlich', 'soviel ich weiß', 'ja'], // 7: sport
  ['soviel ich weiß', 'bekanntlich', 'soviel ich weiß', 'ja'], // 8: lokalkauf
];

// ── Critical items (IDs 1–8) ────────────────────────────────────────────────
// Listener perspective: "Du hörst, wie deine Kollegin/dein Kollege ..."
// contexts[]: [pc_prag low, pc_prag high]

const CRITICAL_ITEMS = [
  // ── Item 1: Klimawandel ──────────────────────────────────────────────────
  {
    id: 1,
    topic: 'klimawandel',
    sentenceBefore: 'Der Klimawandel wird',
    sentenceAfter:  'durch menschliche Aktivitäten verursacht.',
    q: 'auf Flugreisen verzichten',
    contexts: [
      'Du hörst, wie dein Kollege mit einem anderen Kollegen über den Klimawandel spricht. ' +
      'In eurem Kollegenkreis teilen die meisten die Ansicht, ' +
      'dass der Klimawandel durch menschliche Aktivitäten verursacht wird.',

      'Du hörst, wie dein Kollege mit einem anderen Kollegen über den Klimawandel spricht. ' +
      'In eurem Kollegenkreis gehen die Meinungen dazu allerdings stark auseinander.',
    ],
  },

  // ── Item 2: Ernährung ────────────────────────────────────────────────────
  {
    id: 2,
    topic: 'ernaehrung',
    sentenceBefore: 'Eine überwiegend pflanzliche Ernährung fördert',
    sentenceAfter:  'die Gesundheit.',
    q: 'mehr pflanzliche Lebensmittel in deinen Alltag einbauen',
    contexts: [
      'Du hörst, wie deine Kollegin mit einer Freundin über Ernährungsgewohnheiten spricht. ' +
      'In eurem Freundeskreis teilen die meisten die Überzeugung, ' +
      'dass eine überwiegend pflanzliche Ernährung die Gesundheit fördert.',

      'Du hörst, wie deine Kollegin mit einer Freundin über Ernährungsgewohnheiten spricht. ' +
      'In eurem Freundeskreis herrschen dazu sehr unterschiedliche Meinungen.',
    ],
  },

  // ── Item 3: Stadtverkehr ─────────────────────────────────────────────────
  {
    id: 3,
    topic: 'stadtverkehr',
    sentenceBefore: 'Ein ausgebautes Nahverkehrsnetz entlastet',
    sentenceAfter:  'den Stadtverkehr deutlich.',
    q: 'häufiger auf öffentliche Verkehrsmittel umsteigen',
    contexts: [
      'Du hörst, wie dein Nachbar mit einem anderen Nachbarn über Verkehrspolitik in eurer Stadt spricht. ' +
      'In eurer Nachbarschaft sehen das die meisten ähnlich, ' +
      'dass ein ausgebautes Nahverkehrsnetz den Stadtverkehr deutlich entlastet.',

      'Du hörst, wie dein Nachbar mit einem anderen Nachbarn über Verkehrspolitik in eurer Stadt spricht. ' +
      'In eurer Nachbarschaft gehen die Meinungen dazu weit auseinander.',
    ],
  },

  // ── Item 4: Digitalisierung ──────────────────────────────────────────────
  {
    id: 4,
    topic: 'digitalisierung',
    sentenceBefore: 'Digitale Kompetenzen sind',
    sentenceAfter:  'in der heutigen Arbeitswelt unverzichtbar.',
    q: 'regelmäßig digitale Weiterbildungsangebote nutzen',
    contexts: [
      'Du hörst, wie deine Kollegin mit einer anderen Kollegin über Berufsausbildung und Weiterbildung spricht. ' +
      'In eurem Team teilen die meisten die Ansicht, ' +
      'dass digitale Kompetenzen in der heutigen Arbeitswelt unverzichtbar sind.',

      'Du hörst, wie deine Kollegin mit einer anderen Kollegin über Berufsausbildung und Weiterbildung spricht. ' +
      'In eurem Team gehen die Meinungen dazu stark auseinander.',
    ],
  },

  // ── Item 5: Schlaf ───────────────────────────────────────────────────────
  {
    id: 5,
    topic: 'schlaf',
    sentenceBefore: 'Ausreichend Schlaf ist',
    sentenceAfter:  'entscheidend für die kognitive Leistungsfähigkeit.',
    q: 'auf feste Schlafzeiten achten',
    contexts: [
      'Du hörst, wie dein Bekannter mit einem anderen Bekannten über Gesundheit und Wohlbefinden spricht. ' +
      'In deinem Bekanntenkreis teilen die meisten die Ansicht, ' +
      'dass ausreichend Schlaf entscheidend für die kognitive Leistungsfähigkeit ist.',

      'Du hörst, wie dein Bekannter mit einem anderen Bekannten über Gesundheit und Wohlbefinden spricht. ' +
      'In deinem Bekanntenkreis gehen die Meinungen dazu stark auseinander.',
    ],
  },

  // ── Item 6: Plastik ──────────────────────────────────────────────────────
  {
    id: 6,
    topic: 'plastik',
    sentenceBefore: 'Einwegplastik schadet',
    sentenceAfter:  'den Meeresökosystemen erheblich.',
    q: 'konsequent auf Einwegplastik verzichten',
    contexts: [
      'Du hörst, wie deine Freundin mit einer anderen Freundin über Umweltschutz spricht. ' +
      'In eurem Freundeskreis teilen die meisten die Überzeugung, ' +
      'dass Einwegplastik den Meeresökosystemen erheblich schadet.',

      'Du hörst, wie deine Freundin mit einer anderen Freundin über Umweltschutz spricht. ' +
      'In eurem Freundeskreis herrschen dazu sehr unterschiedliche Meinungen.',
    ],
  },

  // ── Item 7: Sport ────────────────────────────────────────────────────────
  {
    id: 7,
    topic: 'sport',
    sentenceBefore: 'Regelmäßige körperliche Bewegung senkt',
    sentenceAfter:  'das Risiko für Herz-Kreislauf-Erkrankungen deutlich.',
    q: 'regelmäßig Sport in deinen Alltag integrieren',
    contexts: [
      'Du hörst, wie dein Kollege mit einem Arbeitskollegen über gesunden Lebensstil spricht. ' +
      'In eurem Kollegenkreis teilen die meisten die Ansicht, ' +
      'dass regelmäßige körperliche Bewegung das Risiko für Herz-Kreislauf-Erkrankungen deutlich senkt.',

      'Du hörst, wie dein Kollege mit einem Arbeitskollegen über gesunden Lebensstil spricht. ' +
      'In eurem Kollegenkreis gehen die Meinungen dazu stark auseinander.',
    ],
  },

  // ── Item 8: Lokalkauf ────────────────────────────────────────────────────
  {
    id: 8,
    topic: 'lokalkauf',
    sentenceBefore: 'Das Kaufen bei lokalen Händlern stärkt',
    sentenceAfter:  'die regionale Wirtschaft nachhaltig.',
    q: 'öfter bei lokalen Geschäften einkaufen',
    contexts: [
      'Du hörst, wie dein Nachbar mit einem anderen Nachbarn über Einkaufsgewohnheiten spricht. ' +
      'In eurer Nachbarschaft teilen die meisten die Überzeugung, ' +
      'dass das Kaufen bei lokalen Händlern die regionale Wirtschaft nachhaltig stärkt.',

      'Du hörst, wie dein Nachbar mit einem anderen Nachbarn über Einkaufsgewohnheiten spricht. ' +
      'In eurer Nachbarschaft gehen die Meinungen dazu weit auseinander.',
    ],
  },
];

// ── Latin square rotation ────────────────────────────────────────────────────
// Returns 8 trial objects for the given list number (0–3).
export function getCriticalTrials(listNum) {
  return CRITICAL_ITEMS.map((item, i) => {
    const conditionIndex = (i + listNum) % 4;
    const cond = CONDITIONS[conditionIndex];
    const contextIndex = conditionIndex >> 1; // 0,1 → 0 (low); 2,3 → 1 (high)
    const marker = MARKER_ASSIGNMENT[i][conditionIndex];
    return {
      id: item.id,
      topic: item.topic,
      is_filler: false,
      pc_prag: cond.pc_prag,
      g_implied: cond.g_implied,
      condition_index: conditionIndex,
      context: item.contexts[contextIndex],
      marker,
      sentenceBefore: item.sentenceBefore,
      sentenceAfter: item.sentenceAfter,
      q: item.q,
    };
  });
}

// ── Filler items (IDs 101–108) ───────────────────────────────────────────────
// Listener perspective. Randomly assigned marker (no condition structure).
const FILLER_MARKERS = ['soviel ich weiß', 'ja', 'bekanntlich'];

function randomFillerMarker() {
  return FILLER_MARKERS[Math.floor(Math.random() * FILLER_MARKERS.length)];
}

export function getFillers() {
  return [
    {
      id: 101,
      topic: 'bahn',
      is_filler: true,
      pc_prag: null, g_implied: null, condition_index: null,
      context:
        'Du hörst, wie deine Freundin mit einer anderen Freundin über Reisemöglichkeiten in Deutschland spricht. ' +
        'Sie überlegt, wie sie umweltfreundlich von München nach Hamburg kommen kann.',
      marker: randomFillerMarker(),
      sentenceBefore: 'Der Zug ist',
      sentenceAfter:  'für Reisen innerhalb Deutschlands sehr praktisch.',
      q: 'häufiger mit der Bahn reisen',
    },
    {
      id: 102,
      topic: 'leselicht',
      is_filler: true,
      pc_prag: null, g_implied: null, condition_index: null,
      context:
        'Du hörst, wie deine Kollegin mit ihrer jüngeren Schwester spricht, ' +
        'die sich über Kopfschmerzen beim Lesen beklagt.',
      marker: randomFillerMarker(),
      sentenceBefore: 'Gutes Licht beim Lesen schont',
      sentenceAfter:  'die Augen.',
      q: 'dir eine bessere Leselampe anschaffen',
    },
    {
      id: 103,
      topic: 'kochen',
      is_filler: true,
      pc_prag: null, g_implied: null, condition_index: null,
      context:
        'Du hörst, wie dein Kollege mit einem Studienfreund über seinen Ernährungsalltag spricht. ' +
        'Der Freund klagt, dass sein Geld für Essen kaum reicht.',
      marker: randomFillerMarker(),
      sentenceBefore: 'Frisch kochen spart',
      sentenceAfter:  'auf Dauer Geld im Vergleich zu Fertiggerichten.',
      q: 'öfter selbst kochen',
    },
    {
      id: 104,
      topic: 'kaffee',
      is_filler: true,
      pc_prag: null, g_implied: null, condition_index: null,
      context:
        'Du hörst, wie deine Kollegin mit einer anderen Kollegin spricht, ' +
        'die morgens immer sehr müde ist. Ihr seid alle an der Kaffeemaschine im Büro.',
      marker: randomFillerMarker(),
      sentenceBefore: 'Ein Kaffee am Morgen hilft',
      sentenceAfter:  'vielen Menschen, wach zu werden.',
      q: 'morgens eine kleine Kaffeepause einplanen',
    },
    {
      id: 105,
      topic: 'urlaub',
      is_filler: true,
      pc_prag: null, g_implied: null, condition_index: null,
      context:
        'Du hörst, wie dein Freund mit einem anderen Freund spricht, ' +
        'der seit Monaten ohne Urlaub durcharbeitet und erschöpft wirkt.',
      marker: randomFillerMarker(),
      sentenceBefore: 'Regelmäßige Auszeiten tun',
      sentenceAfter:  'der mentalen Gesundheit gut.',
      q: 'dieses Jahr endlich Urlaub nehmen',
    },
    {
      id: 106,
      topic: 'trinken',
      is_filler: true,
      pc_prag: null, g_implied: null, condition_index: null,
      context:
        'Du hörst, wie dein Mitbewohner mit einem anderen Mitbewohner spricht, ' +
        'der sich nachmittags immer schlapp und unkonzentriert fühlt.',
      marker: randomFillerMarker(),
      sentenceBefore: 'Genügend Wasser zu trinken verbessert',
      sentenceAfter:  'die Konzentrationsfähigkeit.',
      q: 'öfter ein Glas Wasser trinken',
    },
    {
      id: 107,
      topic: 'frischluft',
      is_filler: true,
      pc_prag: null, g_implied: null, condition_index: null,
      context:
        'Du hörst, wie dein Kollege mit einer Kollegin spricht, die sich ' +
        'in eurem schlecht belüfteten Großraumbüro häufig unwohl fühlt.',
      marker: randomFillerMarker(),
      sentenceBefore: 'Regelmäßiges Lüften verbessert',
      sentenceAfter:  'die Raumluftqualität merklich.',
      q: 'dein Büro öfter lüften',
    },
    {
      id: 108,
      topic: 'laerm',
      is_filler: true,
      pc_prag: null, g_implied: null, condition_index: null,
      context:
        'Du hörst, wie deine Kollegin mit ihrer jüngeren Nichte spricht, ' +
        'die ständig mit voller Lautstärke Musik über Kopfhörer hört.',
      marker: randomFillerMarker(),
      sentenceBefore: 'Laute Musik in Kopfhörern schädigt',
      sentenceAfter:  'auf Dauer das Gehör.',
      q: 'die Lautstärke beim Musikhören reduzieren',
    },
  ];
}
