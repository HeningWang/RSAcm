// norming_exp/src/stimuli.js
//
// AUTO-GENERATED from items.csv — do not edit manually.
// Run: python experiments/item/generate_stimuli.py
//
// Norming study: elicit participants' prior beliefs about propositional
// common ground (pc_prop) for each of the 8 critical topics.
//
// Task: For each claim, participants rate perceived social consensus on a 0-100 slider:
//   "Wie sehr gilt diese Aussage Ihrer Meinung nach als allgemein anerkannt?"
//   (0 = überhaupt nicht anerkannt ... 100 = vollständig anerkannt)
//
// All 8 items are shown to every participant in randomised order (no Latin square).
// The resulting mean pc_prop_rating per topic replace the binary pc_prop manipulation
// in the production experiment with a continuous predictor.

export const ITEMS = [
  {
    id: 1,
    topic: 'klimawandel',
    claim: 'Der Klimawandel wird durch menschliche Aktivitäten verursacht.'
  },
  {
    id: 2,
    topic: 'ernaehrung',
    claim: 'Eine überwiegend pflanzliche Ernährung fördert die Gesundheit.'
  },
  {
    id: 3,
    topic: 'stadtverkehr',
    claim: 'Ein ausgebautes Nahverkehrsnetz entlastet den Stadtverkehr erheblich.'
  },
  {
    id: 4,
    topic: 'digitalisierung',
    claim: 'Digitale Kompetenzen sind in der heutigen Arbeitswelt unverzichtbar.'
  },
  {
    id: 5,
    topic: 'schlaf',
    claim: 'Ausreichend Schlaf ist entscheidend für die kognitive Leistungsfähigkeit.'
  },
  {
    id: 6,
    topic: 'plastik',
    claim: 'Einwegplastik schadet den Meeresökosystemen erheblich.'
  },
  {
    id: 7,
    topic: 'sport',
    claim: 'Regelmäßige körperliche Bewegung senkt das Risiko für Herz-Kreislauf-Erkrankungen deutlich.'
  },
  {
    id: 8,
    topic: 'lokalkauf',
    claim: 'Der Einkauf bei lokalen Händlern stärkt die regionale Wirtschaft nachhaltig.'
  },
];
