<template>
  <Experiment title="Konsensmarker-Produktionsstudie">

    <!-- ── 1. Instructions ─────────────────────────────────────────── -->
    <InstructionScreen :title="'Willkommen zur Studie!'">
      <p>
        In dieser Studie untersuchen wir, wie Sprecherinnen und Sprecher des Deutschen
        bestimmte sprachliche Ausdrücke verwenden, um auf geteiltes Wissen hinzuweisen.
      </p>
      <p>
        Du wirst in <strong>{{ shuffledTrials.length }} verschiedene Alltagssituationen</strong>
        versetzt. Oben im <strong>blauen Kasten</strong> findest du jeweils den
        Hintergrundtext zur Situation.
      </p>
      <p>
        Deine Aufgabe ist es, den Hintergrundtext sorgfältig zu lesen und dann
        im Satz darunter aus dem Dropdown-Menü den Ausdruck auszuwählen, den du
        in dieser Situation am natürlichsten finden würdest.
      </p>
      <p>
        Zuerst bearbeitest du eine <strong>kurze Übungsaufgabe</strong>, damit du
        dich mit dem Aufbau vertraut machen kannst.
      </p>
      <p>
        Es gibt keine richtigen oder falschen Antworten. Bitte antworte spontan und auf Deutsch!
      </p>
      <p>
        Die Teilnahme dauert etwa <strong>5–10 Minuten</strong>. Vielen Dank für deine Mitarbeit!
      </p>
    </InstructionScreen>

    <!-- ── 2. Training trial ──────────────────────────────────────── -->
    <Screen>
      <Slide>
        <div class="trial-header">
          Übung
        </div>

        <p class="training-note">
          Im blauen Kasten steht der Hintergrundtext. Wähle anschließend im Satz
          darunter den Ausdruck aus, der für dich am natürlichsten klingt.
        </p>

        <div class="context-box">
          <p class="context-text">{{ trainingTrial.context }}</p>
          <p class="goal-instruction">
            <em>{{ trainingTrial.goalInstruction }}</em>
          </p>
        </div>

        <div class="sentence-frame">
          <p class="frame-label">
            Welchen Ausdruck würdest du in dieser Situation verwenden?
          </p>
          <p class="frame-sentence">
            <span class="frame-text">{{ trainingTrial.sentenceBefore }} </span><select
              v-model="trainingSelection"
              class="marker-select"
            ><option value="" disabled>___</option><option
                v-for="m in trainingOptions"
                :key="m"
                :value="m"
              >{{ m }}</option></select><span class="frame-text"> {{ trainingTrial.sentenceAfter }}</span>
          </p>
          <p class="frame-consequent">Deshalb solltest du {{ trainingTrial.q }}.</p>
        </div>

        <div class="btn-row">
          <button
            class="next-btn"
            :disabled="!trainingSelection"
            @click="recordTrainingAndAdvance"
          >
            Weiter →
          </button>
        </div>
      </Slide>
    </Screen>

    <!-- ── 3. Transition screen ───────────────────────────────────── -->
    <Screen>
      <Slide>
        <div class="transition-screen">
          <h2 class="transition-title">
            Die Übung ist abgeschlossen.
          </h2>
          <p class="transition-text">
            Als Nächstes beginnen die eigentlichen Versuchsdurchgänge.
          </p>
          <p class="transition-text">
            Lies wieder jeweils zuerst den Hintergrundtext im blauen Kasten und
            wähle dann den Ausdruck aus, der in der Situation für dich am
            natürlichsten klingt.
          </p>

          <div class="btn-row transition-btn-row">
            <button
              class="next-btn"
              @click="$magpie.nextScreen()"
            >
              Studie starten →
            </button>
          </div>
        </div>
      </Slide>
    </Screen>

    <!-- ── 4. Trial Screens (one per stimulus) ────────────────────── -->
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
            Welchen Ausdruck würdest du in dieser Situation verwenden?
          </p>
          <p class="frame-sentence">
            <span class="frame-text">{{ trial.sentenceBefore }} </span><select
              v-model="selectedMarkers[trial.id]"
              class="marker-select"
            ><option value="" disabled>___</option><option
                v-for="m in markerOptions[trial.id]"
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

    <!-- ── 5. Post-test ────────────────────────────────────────────── -->
    <PostTestScreen :gender="false" />

    <!-- ── 6. Submit ──────────────────────────────────────────────── -->
    <SubmitResultsScreen />

  </Experiment>
</template>

<script>
import _ from 'lodash';
import { getCriticalTrials, FILLERS } from './stimuli.js';

const MARKERS = [
  'soviel ich weiß',
  'ja',
  'bekanntlich',
];

const TRAINING_TRIAL = {
  id: 'training',
  topic: 'konzentration',
  is_filler: false,
  is_training: true,
  condition_index: null,
  pc_prag: 'low',
  g: 'low',
  context:
    'Du sprichst mit einem/einer Gesprächspartner/in über einen anstrengenden Arbeitstag. Ihr überlegt gemeinsam, was helfen könnte, um zwischendurch wieder konzentrierter zu sein.',
  goalInstruction: 'Du möchtest einen Vorschlag machen und diesen nur kurz anmerken.',
  sentenceBefore: 'Kurze Pausen an der frischen Luft verbessern',
  sentenceAfter: 'die Konzentration im Arbeitsalltag.',
  q: 'in deiner Mittagspause kurz nach draußen gehen',
};

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
      trainingTrial: TRAINING_TRIAL,
      trainingSelection: '',
      trainingOptions: [],
      shuffledTrials: [],
      selectedMarkers: {},   // { [trial.id]: marker string }
      markerOptions: {},     // { [trial.id]: string[] }
      trialStartTime: null,
    };
  },
  created() {
    this.listNum = resolveListNum();
    this.trainingOptions = _.shuffle([...MARKERS]);
    // Record list number at experiment level so it appears in every data row
    this.$magpie.addExpData({ list_num: this.listNum });
    // Build trial sequence: 8 critical (Latin square) + 8 fillers, shuffled
    const critical = getCriticalTrials(this.listNum);
    this.shuffledTrials = _.shuffle([...critical, ...FILLERS]);
    // Pre-initialise selectedMarkers keys for Vue 2 reactivity
    this.shuffledTrials.forEach((trial) => {
      this.$set(this.selectedMarkers, trial.id, '');
      this.$set(this.markerOptions, trial.id, _.shuffle([...MARKERS]));
    });
    this.trialStartTime = Date.now();
  },
  methods: {
    recordTrainingAndAdvance() {
      const rt = Date.now() - this.trialStartTime;
      this.$magpie.addTrialData({
        trial_index: 0,
        trial_id: this.trainingTrial.id,
        topic: this.trainingTrial.topic,
        is_filler: this.trainingTrial.is_filler,
        is_training: true,
        condition_index: this.trainingTrial.condition_index,
        pc_prag: this.trainingTrial.pc_prag,
        g: this.trainingTrial.g,
        selected_marker: this.trainingSelection,
        sentence: `${this.trainingTrial.sentenceBefore} ${this.trainingSelection} ${this.trainingTrial.sentenceAfter}`,
        rt,
      });
      this.trialStartTime = Date.now();
      this.$magpie.nextScreen();
    },
    recordAndAdvance(trial, index) {
      const rt = Date.now() - this.trialStartTime;
      this.$magpie.addTrialData({
        trial_index: index + 1,
        trial_id: trial.id,
        topic: trial.topic,
        is_filler: trial.is_filler,
        is_training: false,
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

.training-note {
  margin: 0 0 1em 0;
  color: #2f4f75;
  font-size: 0.98em;
}

.transition-screen {
  min-height: 60vh;
  max-width: 42rem;
  margin: 0 auto;
  display: flex;
  flex-direction: column;
  justify-content: center;
  text-align: center;
}

.transition-title {
  margin: 0 0 0.8em 0;
  color: #1f3552;
}

.transition-text {
  margin: 0 0 0.9em 0;
  line-height: 1.6;
  color: #333;
}

.transition-btn-row {
  margin-top: 1.5em;
  justify-content: center;
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
  font-weight: 700;
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
