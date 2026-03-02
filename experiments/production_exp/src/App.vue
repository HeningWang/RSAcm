<template>
  <Experiment title="Konsensmarker-Studie">

    <!-- ── 1. Instructions ─────────────────────────────────────────── -->
    <InstructionScreen :title="'Willkommen zur Studie!'">
      <p>
        In dieser Studie untersuchen wir, wie Sprecherinnen und Sprecher des Deutschen
        bestimmte sprachliche Ausdrücke verwenden, um auf geteiltes Wissen hinzuweisen.
      </p>
      <p>
        Sie werden in <strong>{{ shuffledTrials.length }} verschiedene Alltagssituationen</strong>
        versetzt. Lesen Sie jede Situation sorgfältig durch und wählen Sie dann aus dem
        Dropdown-Menü den Ausdruck aus, den Sie in dieser Situation am natürlichsten finden würden.
      </p>
      <p>
        Es gibt keine richtigen oder falschen Antworten – uns interessiert Ihr persönliches
        Sprachgefühl. Bitte antworten Sie spontan und auf Deutsch.
      </p>
      <p>
        Die Teilnahme dauert etwa <strong>10–15 Minuten</strong>. Vielen Dank für Ihre Mitarbeit!
      </p>
    </InstructionScreen>

    <!-- ── 2. Trial Screens (one per stimulus) ────────────────────── -->
    <Screen
      v-for="(trial, i) in shuffledTrials"
      :key="trial.id"
    >
      <Slide>
        <div class="trial-header">
          Situation {{ i + 1 }} von {{ shuffledTrials.length }}
        </div>

        <div class="context-box">
          <p class="context-text">{{ trial.context }}</p>
          <p class="goal-instruction">
            <em>{{ trial.goalInstruction }}</em>
          </p>
        </div>

        <div class="sentence-frame">
          <p class="frame-label">
            Welchen Ausdruck würden Sie in dieser Situation verwenden?
          </p>
          <p class="frame-sentence">
            <span class="frame-text">{{ trial.sentenceBefore }} </span><select
              v-model="selectedMarkers[trial.id]"
              class="marker-select"
            ><option value="" disabled>___</option><option
                v-for="m in markers"
                :key="m"
                :value="m"
              >{{ m }}</option></select><span class="frame-text"> {{ trial.sentenceAfter }}</span>
          </p>
          <p class="frame-consequent">Deshalb solltest du {{ trial.q }}.</p>
        </div>

        <div class="btn-row">
          <button
            class="next-btn"
            :disabled="!selectedMarkers[trial.id]"
            @click="recordAndAdvance(trial, i)"
          >
            Weiter →
          </button>
        </div>
      </Slide>
    </Screen>

    <!-- ── 3. Post-test ────────────────────────────────────────────── -->
    <PostTestScreen />

    <!-- ── 4. Submit ──────────────────────────────────────────────── -->
    <SubmitResultsScreen />

  </Experiment>
</template>

<script>
import _ from 'lodash';
import { getCriticalTrials, FILLERS } from './stimuli.js';

const MARKERS = [
  'sofern ich weiß',
  'wie du ja weißt',
  'wie wir wissen',
  'ja',
  'bekanntlichermaßen',
];

// Read ?list=N from URL; fall back to random 0–3.
function resolveListNum() {
  const params = new URLSearchParams(window.location.search);
  const parsed = parseInt(params.get('list'), 10);
  return Number.isInteger(parsed) && parsed >= 0 && parsed <= 3
    ? parsed
    : Math.floor(Math.random() * 4);
}

export default {
  name: 'App',
  data() {
    return {
      listNum: null,
      shuffledTrials: [],
      selectedMarkers: {},   // { [trial.id]: marker string }
      markers: MARKERS,
      trialStartTime: null,
    };
  },
  created() {
    this.listNum = resolveListNum();
    // Record list number at experiment level so it appears in every data row
    this.$magpie.addExpData({ list_num: this.listNum });
    // Build trial sequence: 8 critical (Latin square) + 8 fillers, shuffled
    const critical = getCriticalTrials(this.listNum);
    this.shuffledTrials = _.shuffle([...critical, ...FILLERS]);
    // Pre-initialise selectedMarkers keys for Vue 2 reactivity
    this.shuffledTrials.forEach((trial) => {
      this.$set(this.selectedMarkers, trial.id, '');
    });
    this.trialStartTime = Date.now();
  },
  methods: {
    recordAndAdvance(trial, index) {
      const rt = Date.now() - this.trialStartTime;
      this.$magpie.addTrialData({
        trial_index: index + 1,
        trial_id: trial.id,
        topic: trial.topic,
        is_filler: trial.is_filler,
        condition_index: trial.condition_index,
        pc_prag: trial.pc_prag,
        g: trial.g,
        selected_marker: this.selectedMarkers[trial.id],
        sentence: `${trial.sentenceBefore} ${this.selectedMarkers[trial.id]} ${trial.sentenceAfter}`,
        rt,
      });
      this.trialStartTime = Date.now();
      this.$magpie.nextScreen();
    },
  },
};
</script>

<style scoped>
.trial-header {
  color: #888;
  font-size: 0.85em;
  margin-bottom: 1.2em;
  letter-spacing: 0.03em;
}

.context-box {
  background: #f0f4fa;
  border-left: 4px solid #4a7ec0;
  padding: 1em 1.4em;
  margin-bottom: 1.6em;
  border-radius: 0 6px 6px 0;
  line-height: 1.6;
}

.context-text {
  margin: 0 0 0.7em 0;
  color: #222;
}

.goal-instruction {
  margin: 0;
  color: #444;
}

.sentence-frame {
  margin-bottom: 2em;
}

.frame-label {
  margin-bottom: 0.6em;
  font-weight: 500;
}

.frame-sentence {
  font-size: 1.05em;
  line-height: 1.8;
  margin: 0 0 0.4em 0;
}

.frame-consequent {
  font-size: 1.05em;
  font-style: italic;
  color: #555;
  margin: 0;
}

.marker-select {
  font-size: 1em;
  padding: 0.35em 0.7em;
  border: 2px solid #4a7ec0;
  border-radius: 5px;
  background: #fff;
  cursor: pointer;
  color: #222;
}

.frame-text {
  font-style: italic;
  color: #333;
}

.btn-row {
  display: flex;
  justify-content: flex-end;
}

.next-btn {
  padding: 0.55em 1.6em;
  font-size: 1em;
  background: #4a7ec0;
  color: #fff;
  border: none;
  border-radius: 5px;
  cursor: pointer;
  transition: background 0.15s;
}

.next-btn:hover:not(:disabled) {
  background: #3464a0;
}

.next-btn:disabled {
  background: #bbb;
  cursor: not-allowed;
}
</style>
