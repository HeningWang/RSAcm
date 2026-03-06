#!/usr/bin/env python3
"""
Generate stimuli.js for all three experiments from items.csv.

Usage:
    python generate_stimuli.py

Reads:  experiments/item/items.csv
Writes: experiments/norming_exp/src/stimuli.js
        experiments/production_exp/src/stimuli.js
        experiments/comprehension_exp/src/stimuli.js
"""

import csv
import json
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
CSV_PATH = SCRIPT_DIR / "items.csv"
EXP_ROOT = SCRIPT_DIR.parent


def load_items():
    with open(CSV_PATH, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        rows = list(reader)
    critical = [r for r in rows if r["item_type"] == "critical"]
    fillers = [r for r in rows if r["item_type"] == "filler"]
    return critical, fillers


def js_string(s):
    """Escape a string for JS single-quoted literal."""
    return s.replace("\\", "\\\\").replace("'", "\\'")


# ── Norming ──────────────────────────────────────────────────────────────────

def generate_norming(critical):
    lines = [
        "// norming_exp/src/stimuli.js",
        "//",
        "// AUTO-GENERATED from items.csv — do not edit manually.",
        "// Run: python experiments/item/generate_stimuli.py",
        "//",
        "// Norming study: elicit participants' prior beliefs about propositional",
        "// common ground (pc_prop) for each of the 8 critical topics.",
        "//",
        "// Task: For each claim, participants rate perceived social consensus on a 0-100 slider:",
        "//   \"Wie sehr gilt diese Aussage Ihrer Meinung nach als allgemein anerkannt?\"",
        "//   (0 = überhaupt nicht anerkannt ... 100 = vollständig anerkannt)",
        "//",
        "// All 8 items are shown to every participant in randomised order (no Latin square).",
        "// The resulting mean pc_prop_rating per topic replace the binary pc_prop manipulation",
        "// in the production experiment with a continuous predictor.",
        "",
        "export const ITEMS = [",
    ]
    for row in critical:
        claim = js_string(row["norming_claim"])
        lines.append("  {")
        lines.append(f"    id: {row['item_id']},")
        lines.append(f"    topic: '{row['topic']}',")
        lines.append(f"    claim: '{claim}'")
        lines.append("  },")
    lines.append("];")
    lines.append("")
    return "\n".join(lines)


# ── Production ───────────────────────────────────────────────────────────────

def generate_production(critical, fillers):
    lines = [
        "// production_exp/src/stimuli.js",
        "//",
        "// AUTO-GENERATED from items.csv — do not edit manually.",
        "// Run: python experiments/item/generate_stimuli.py",
        "//",
        "// Latin square design: 8 critical items x 4 conditions, 4 lists.",
        "// Each participant sees 8 critical trials (one per item, one per condition)",
        "// plus 8 fillers, shuffled -> 16 trials total.",
        "//",
        "// List assignment: getCriticalTrials(listNum) implements the rotation.",
        "// In list l, item i gets condition (i + l) % 4.",
        "//",
        "// Conditions are encoded as a 2-bit index:",
        "//   bit 1 = pc_prag  (0 = low, 1 = high)",
        "//   bit 0 = g        (0 = low, 1 = high)",
        "//",
        "//   0 = low  / low",
        "//   1 = low  / high",
        "//   2 = high / low",
        "//   3 = high / high",
        "//",
        "// pc_prop is no longer a within-experiment manipulation.",
        "// A continuous pc_prop_rating (0-100) for each topic is obtained from the",
        "// separate norming study and used as a continuous predictor in analysis.",
        "//",
        "// Each critical item carries 2 context strings indexed by pc_prag:",
        "//   [0] pc_prag: low   (social circle mostly shares the view)",
        "//   [1] pc_prag: high  (social circle opinions diverge)",
        "// The contextIndex = conditionIndex >> 1 (strips the g bit).",
        "",
    ]

    # Goal instructions — extract from first filler rows
    goal_low = js_string(critical[0]["goal_instruction_low"])
    goal_high = js_string(critical[0]["goal_instruction_high"])
    lines.append(f"const GOAL_LOW  = '{goal_low}';")
    lines.append(f"const GOAL_HIGH = '{goal_high}';")
    lines.append("")
    lines.append("const CONDITIONS = [")
    lines.append("  { pc_prag: 'low',  g: 'low',  goalInstruction: GOAL_LOW  }, // 0")
    lines.append("  { pc_prag: 'low',  g: 'high', goalInstruction: GOAL_HIGH }, // 1")
    lines.append("  { pc_prag: 'high', g: 'low',  goalInstruction: GOAL_LOW  }, // 2")
    lines.append("  { pc_prag: 'high', g: 'high', goalInstruction: GOAL_HIGH }, // 3")
    lines.append("];")
    lines.append("")

    # Critical items
    lines.append("// ── Critical items (IDs 1-8) ─────────────────────────────────────────────────")
    lines.append("// contexts[]: [pc_prag low, pc_prag high]")
    lines.append("")
    lines.append("const CRITICAL_ITEMS = [")
    for row in critical:
        topic = row["topic"]
        lines.append(f"  // ── Item {row['item_id']}: {topic.capitalize()} {'─' * (60 - len(topic))}")
        lines.append("  {")
        lines.append(f"    id: {row['item_id']},")
        lines.append(f"    topic: '{topic}',")
        lines.append(f"    sentenceBefore: '{js_string(row['sentence_before'])}',")
        lines.append(f"    sentenceAfter:  '{js_string(row['sentence_after'])}',")
        lines.append(f"    q: '{js_string(row['q'])}',")
        lines.append("    contexts: [")
        ctx_low = js_string(row["context_pc_prag_low"])
        ctx_high = js_string(row["context_pc_prag_high"])
        lines.append(f"      '{ctx_low}',")
        lines.append("")
        lines.append(f"      '{ctx_high}',")
        lines.append("    ],")
        lines.append("  },")
        lines.append("")
    lines.append("];")
    lines.append("")

    # Latin square function
    lines.append("// ── Latin square rotation ────────────────────────────────────────────────────")
    lines.append("// Returns 8 trial objects for the given list number (0-3).")
    lines.append("// Item i is shown in condition (i + listNum) % 4.")
    lines.append("export function getCriticalTrials(listNum) {")
    lines.append("  return CRITICAL_ITEMS.map((item, i) => {")
    lines.append("    const conditionIndex = (i + listNum) % 4;")
    lines.append("    const cond = CONDITIONS[conditionIndex];")
    lines.append("    // contextIndex = pc_prag bit = conditionIndex >> 1")
    lines.append("    //   0,1 -> 0 (pc_prag low)   2,3 -> 1 (pc_prag high)")
    lines.append("    const contextIndex = conditionIndex >> 1;")
    lines.append("    return {")
    lines.append("      id: item.id,")
    lines.append("      topic: item.topic,")
    lines.append("      is_filler: false,")
    lines.append("      pc_prag: cond.pc_prag,")
    lines.append("      g: cond.g,")
    lines.append("      condition_index: conditionIndex,")
    lines.append("      context: item.contexts[contextIndex],")
    lines.append("      goalInstruction: cond.goalInstruction,")
    lines.append("      sentenceBefore: item.sentenceBefore,")
    lines.append("      sentenceAfter: item.sentenceAfter,")
    lines.append("      q: item.q,")
    lines.append("    };")
    lines.append("  });")
    lines.append("}")
    lines.append("")

    # Fillers
    lines.append("// ── Filler items (IDs 101-108) ───────────────────────────────────────────────")
    lines.append("// Fixed context, no condition variation.")
    lines.append("// All q values are bare infinitives (no \"zu\") — matches \"solltest du ___\".")
    lines.append("export const FILLERS = [")
    for row in fillers:
        ctx = js_string(row["filler_context_production"])
        goal = row["filler_goal_instruction"]
        goal_ref = "GOAL_LOW" if "kurz anmerken" in goal else "GOAL_HIGH"
        lines.append("  {")
        lines.append(f"    id: {row['item_id']},")
        lines.append(f"    topic: '{row['topic']}',")
        lines.append("    is_filler: true,")
        lines.append("    pc_prag: null, g: null, condition_index: null,")
        lines.append("    context:")
        lines.append(f"      '{ctx}',")
        lines.append(f"    goalInstruction: {goal_ref},")
        lines.append(f"    sentenceBefore: '{js_string(row['sentence_before'])}',")
        lines.append(f"    sentenceAfter:  '{js_string(row['sentence_after'])}',")
        lines.append(f"    q: '{js_string(row['q'])}',")
        lines.append("  },")
    lines.append("];")
    lines.append("")
    return "\n".join(lines)


# ── Comprehension ────────────────────────────────────────────────────────────

def generate_comprehension(critical, fillers):
    lines = [
        "// comprehension_exp/src/stimuli.js",
        "//",
        "// AUTO-GENERATED from items.csv — do not edit manually.",
        "// Run: python experiments/item/generate_stimuli.py",
        "//",
        "// Latin square design: 8 critical items x 4 conditions, 4 lists.",
        "// Each participant sees 8 critical trials (one per item) plus 8 fillers -> 16 trials.",
        "//",
        "// List assignment: getCriticalTrials(listNum) implements the rotation.",
        "// In list l, item i gets condition (i + l) % 4.",
        "//",
        "// Conditions are encoded as a 2-bit index:",
        "//   bit 1 = pc_prag  (0 = low, 1 = high)",
        "//   bit 0 = g_implied (0 = low, 1 = high)",
        "//",
        "//   0 = low  / low",
        "//   1 = low  / high",
        "//   2 = high / low",
        "//   3 = high / high",
        "//",
        "// IMPORTANT: Unlike production, the marker is NOT chosen by the participant.",
        "// It is pre-assigned based on the fitted production model (modal marker for",
        "// each item x condition cell). The MARKER_ASSIGNMENT matrix below is a",
        "// placeholder and MUST be updated after the production model is fitted.",
        "//",
        "// Listener perspective: contexts describe being directly addressed by",
        "// a colleague/friend, rather than being the speaker oneself.",
        "",
        "const CONDITIONS = [",
        "  { pc_prag: 'low',  g_implied: 'low'  }, // 0",
        "  { pc_prag: 'low',  g_implied: 'high' }, // 1",
        "  { pc_prag: 'high', g_implied: 'low'  }, // 2",
        "  { pc_prag: 'high', g_implied: 'high' }, // 3",
        "];",
        "",
        "// ── Marker assignment matrix (8 items x 4 conditions) ──────────────────────",
        "// PLACEHOLDER: Replace with production model results before data collection.",
        "// Each entry is one of: 'soviel ich weiß', 'ja', 'bekanntlich'",
        "//",
        "// markerAssignment[itemIndex][conditionIndex] -> marker string",
        "//",
        "// Current values are illustrative defaults based on theoretical predictions:",
        "//   low pc_prag + low g  -> 'soviel ich weiß' (weakest)",
        "//   low pc_prag + high g -> 'bekanntlich' (strongest)",
        "//   high pc_prag + low g -> 'soviel ich weiß' (weakest)",
        "//   high pc_prag + high g -> 'ja' (middle; attenuated by controversy)",
        "const MARKER_ASSIGNMENT = [",
    ]
    for row in critical:
        lines.append(f"  ['soviel ich weiß', 'bekanntlich', 'soviel ich weiß', 'ja'], // {row['item_id']}: {row['topic']}")
    lines.append("];")
    lines.append("")

    # Critical items
    lines.append("// ── Critical items (IDs 1-8) ────────────────────────────────────────────────")
    lines.append("// Direct-address perspective: the speaker talks directly to the participant.")
    lines.append("// contexts[]: [pc_prag low, pc_prag high]")
    lines.append("")
    lines.append("const CRITICAL_ITEMS = [")
    for row in critical:
        topic = row["topic"]
        lines.append(f"  // ── Item {row['item_id']}: {topic.capitalize()} {'─' * (60 - len(topic))}")
        lines.append("  {")
        lines.append(f"    id: {row['item_id']},")
        lines.append(f"    topic: '{topic}',")
        lines.append(f"    sentenceBefore: '{js_string(row['sentence_before'])}',")
        lines.append(f"    sentenceAfter:  '{js_string(row['sentence_after'])}',")
        lines.append(f"    q: '{js_string(row['q'])}',")
        lines.append("    contexts: [")
        ctx_low = js_string(row["comprehension_context_pc_prag_low"])
        ctx_high = js_string(row["comprehension_context_pc_prag_high"])
        lines.append(f"      '{ctx_low}',")
        lines.append("")
        lines.append(f"      '{ctx_high}',")
        lines.append("    ],")
        lines.append("  },")
        lines.append("")
    lines.append("];")
    lines.append("")

    # Latin square function
    lines.append("// ── Latin square rotation ────────────────────────────────────────────────────")
    lines.append("// Returns 8 trial objects for the given list number (0-3).")
    lines.append("export function getCriticalTrials(listNum) {")
    lines.append("  return CRITICAL_ITEMS.map((item, i) => {")
    lines.append("    const conditionIndex = (i + listNum) % 4;")
    lines.append("    const cond = CONDITIONS[conditionIndex];")
    lines.append("    const contextIndex = conditionIndex >> 1; // 0,1 -> 0 (low); 2,3 -> 1 (high)")
    lines.append("    const marker = MARKER_ASSIGNMENT[i][conditionIndex];")
    lines.append("    return {")
    lines.append("      id: item.id,")
    lines.append("      topic: item.topic,")
    lines.append("      is_filler: false,")
    lines.append("      pc_prag: cond.pc_prag,")
    lines.append("      g_implied: cond.g_implied,")
    lines.append("      condition_index: conditionIndex,")
    lines.append("      context: item.contexts[contextIndex],")
    lines.append("      marker,")
    lines.append("      sentenceBefore: item.sentenceBefore,")
    lines.append("      sentenceAfter: item.sentenceAfter,")
    lines.append("      q: item.q,")
    lines.append("    };")
    lines.append("  });")
    lines.append("}")
    lines.append("")

    # Fillers
    lines.append("// ── Filler items (IDs 101-108) ───────────────────────────────────────────────")
    lines.append("// Direct-address perspective. Randomly assigned marker (no condition structure).")
    lines.append("const FILLER_MARKERS = ['soviel ich weiß', 'ja', 'bekanntlich'];")
    lines.append("")
    lines.append("function randomFillerMarker() {")
    lines.append("  return FILLER_MARKERS[Math.floor(Math.random() * FILLER_MARKERS.length)];")
    lines.append("}")
    lines.append("")
    lines.append("export function getFillers() {")
    lines.append("  return [")
    for row in fillers:
        ctx = js_string(row["filler_context_comprehension"])
        lines.append("    {")
        lines.append(f"      id: {row['item_id']},")
        lines.append(f"      topic: '{row['topic']}',")
        lines.append("      is_filler: true,")
        lines.append("      pc_prag: null, g_implied: null, condition_index: null,")
        lines.append("      context:")
        lines.append(f"        '{ctx}',")
        lines.append("      marker: randomFillerMarker(),")
        lines.append(f"      sentenceBefore: '{js_string(row['sentence_before'])}',")
        lines.append(f"      sentenceAfter:  '{js_string(row['sentence_after'])}',")
        lines.append(f"      q: '{js_string(row['q'])}',")
        lines.append("    },")
    lines.append("  ];")
    lines.append("}")
    lines.append("")
    return "\n".join(lines)


# ── Main ─────────────────────────────────────────────────────────────────────

def main():
    critical, fillers = load_items()

    targets = {
        "norming_exp/src/stimuli.js": generate_norming(critical),
        "production_exp/src/stimuli.js": generate_production(critical, fillers),
        "comprehension_exp/src/stimuli.js": generate_comprehension(critical, fillers),
    }

    for rel_path, content in targets.items():
        out_path = EXP_ROOT / rel_path
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(content, encoding="utf-8")
        print(f"  wrote {out_path.relative_to(EXP_ROOT.parent)}")

    print("Done.")


if __name__ == "__main__":
    main()
