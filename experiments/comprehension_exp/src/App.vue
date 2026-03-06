<template>
  <Experiment title="Konsensmarker – Verständnisstudie">

    <!-- ── 1. Instructions ─────────────────────────────────────────── -->
    <InstructionScreen :title="'Willkommen zur Studie!'">
      <p>
        In dieser Studie untersuchen wir, wie Hörerinnen und Hörer bestimmte
        sprachliche Ausdrücke im Deutschen wahrnehmen.
      </p>
      <p>
        Du wirst in <strong>{{ shuffledTrials.length }} kurze Alltagssituationen</strong>
        versetzt, in denen jemand dir gegenüber eine Aussage macht und daraus
        eine Handlungsempfehlung ableitet. Bitte lies jede Situation
        sorgfältig durch und beantworte anschließend zwei kurze Fragen mithilfe
        eines Schiebereglers.
      </p>
      <p>
        Es gibt keine richtigen oder falschen Antworten – uns interessiert dein
        persönlicher Eindruck. Bitte antworte spontan.
      </p>
      <p>
        Die Teilnahme dauert etwa <strong>5 Minuten</strong>. Vielen Dank für deine Mitarbeit!
      </p>
    </InstructionScreen>

    <!-- ── 2. Trial Screens (one per stimulus) ────────────────────── -->
    <Screen
      v-for="(trial, i) in shuffledTrials"
      :key="trial.id"
    >
      <Slide>
        <div class="trial-header">
          Aussage {{ i + 1 }} von {{ shuffledTrials.length }}
        </div>

        <div class="context-box">
          <p class="context-text">{{ trial.context }}</p>
        </div>

        <div class="utterance-box">
          <p class="speaker-label">Sie/Er sagt zu dir:</p>
          <p class="utterance-text">
            „{{ trial.sentenceBefore }}
            <strong>{{ trial.marker }}</strong>
            {{ trial.sentenceAfter }}
            Deshalb solltest du {{ trial.q }}."
          </p>
        </div>

        <!-- Rating 1: Inferred goal strength -->
        <div class="rating-section">
          <p class="rating-question">
            Wie stark hast du den Eindruck, dass die Sprecherin möchte, dass du
            ihre Empfehlung befolgst?
          </p>
          <div class="slider-wrap">
            <span class="anchor anchor-left">überhaupt<br />nicht</span>
            <input
              v-model.number="ratings_g[trial.id]"
              type="range"
              min="0"
              max="100"
              step="1"
              class="slider"
              @input="sliderTouched_g[trial.id] = true"
            />
            <span class="anchor anchor-right">sehr<br />stark</span>
          </div>
        </div>

        <!-- Rating 2: Adoption likelihood -->
        <div class="rating-section">
          <p class="rating-question">
            Wie wahrscheinlich ist es, dass du die empfohlene Handlung
            tatsächlich umsetzt?
          </p>
          <div class="slider-wrap">
            <span class="anchor anchor-left">sehr<br />unwahrscheinlich</span>
            <input
              v-model.number="ratings_adopt[trial.id]"
              type="range"
              min="0"
              max="100"
              step="1"
              class="slider"
              @input="sliderTouched_adopt[trial.id] = true"
            />
            <span class="anchor anchor-right">sehr<br />wahrscheinlich</span>
          </div>
        </div>

        <div class="btn-row">
          <button
            class="next-btn"
            :disabled="!bothSlidersTouched(trial.id)"
            @click="recordAndAdvance(trial, i)"
          >
            Weiter →
          </button>
        </div>
      </Slide>
    </Screen>

    <!-- ── 3. Post-test ────────────────────────────────────────────── -->
    <PostTestScreen :gender="false" />

    <!-- ── 4. Submit ──────────────────────────────────────────────── -->
    <SubmitResultsScreen />

  </Experiment>
</template>

<script>
import _ from 'lodash';
import { getCriticalTrials, getFillers } from './stimuli.js';

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
      ratings_g: {},          // { [trial.id]: 0–100 }
      ratings_adopt: {},      // { [trial.id]: 0–100 }
      sliderTouched_g: {},    // { [trial.id]: bool }
      sliderTouched_adopt: {},// { [trial.id]: bool }
      trialStartTime: null,
    };
  },
  created() {
    this.listNum = resolveListNum();
    this.$magpie.addExpData({ list_num: this.listNum });

    const critical = getCriticalTrials(this.listNum);
    const fillers = getFillers();
    this.shuffledTrials = _.shuffle([...critical, ...fillers]);

    // Initialise slider values and touch flags for Vue 2 reactivity
    this.shuffledTrials.forEach((trial) => {
      this.$set(this.ratings_g, trial.id, 50);
      this.$set(this.ratings_adopt, trial.id, 50);
      this.$set(this.sliderTouched_g, trial.id, false);
      this.$set(this.sliderTouched_adopt, trial.id, false);
    });
    this.trialStartTime = Date.now();
  },
  methods: {
    bothSlidersTouched(trialId) {
      return this.sliderTouched_g[trialId] && this.sliderTouched_adopt[trialId];
    },
    recordAndAdvance(trial, index) {
      const rt = Date.now() - this.trialStartTime;
      this.$magpie.addTrialData({
        trial_index: index + 1,
        trial_id: trial.id,
        topic: trial.topic,
        is_filler: trial.is_filler,
        condition_index: trial.condition_index,
        pc_prag: trial.pc_prag,
        g_implied: trial.g_implied,
        marker: trial.marker,
        rating_g: this.ratings_g[trial.id],
        rating_adopt: this.ratings_adopt[trial.id],
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
  margin-bottom: 1.2em;
  border-radius: 0 6px 6px 0;
  line-height: 1.6;
}

.context-text {
  margin: 0;
  color: #222;
}

.utterance-box {
  background: #fafafa;
  border: 1px solid #ddd;
  padding: 1em 1.4em;
  margin-bottom: 1.8em;
  border-radius: 6px;
  line-height: 1.6;
}

.speaker-label {
  margin: 0 0 0.4em 0;
  font-weight: 600;
  color: #555;
  font-size: 0.9em;
}

.utterance-text {
  margin: 0;
  font-style: italic;
  color: #222;
  font-size: 1.05em;
}

.rating-section {
  margin-bottom: 1.6em;
}

.rating-question {
  margin-bottom: 0.8em;
  font-weight: 500;
  line-height: 1.5;
}

.slider-wrap {
  display: flex;
  align-items: center;
  gap: 0.8em;
}

.slider {
  flex: 1;
  accent-color: #4a7ec0;
  height: 6px;
  cursor: pointer;
}

.anchor {
  font-size: 0.8em;
  color: #555;
  text-align: center;
  line-height: 1.3;
  min-width: 4em;
}

.anchor-left {
  text-align: right;
}

.anchor-right {
  text-align: left;
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
