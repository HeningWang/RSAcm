<template>
  <Experiment title="Norming-Studie">

    <!-- ── 1. Instructions ─────────────────────────────────────────── -->
    <InstructionScreen :title="'Willkommen zur Studie!'">
      <p>
        In dieser kurzen Studie interessiert uns Ihre persönliche Meinung zu
        einigen Aussagen.
      </p>
      <p>
        Sie sehen nacheinander <strong>{{ shuffledItems.length }} Aussagen</strong>.
        Bitte schätzen Sie für jede Aussage ein, wie sehr sie in der
        Gesellschaft als allgemein anerkannt gilt.
      </p>
      <p>
        Bewegen Sie dazu den Schieberegler auf den Wert, der Ihrem Urteil am
        besten entspricht:
      </p>
      <ul>
        <li><strong>Linkes Ende</strong> – überhaupt nicht anerkannt</li>
        <li><strong>Mitte</strong> – teils anerkannt, teils nicht</li>
        <li><strong>Rechtes Ende</strong> – vollständig anerkannt</li>
      </ul>
      <p>
        Es gibt keine richtigen oder falschen Antworten – uns interessiert Ihr
        persönliches Urteil. Die Teilnahme dauert etwa
        <strong>2 Minuten</strong>. Vielen Dank!
      </p>
    </InstructionScreen>

    <!-- ── 2. Rating Screens (one per claim) ───────────────────────── -->
    <Screen
      v-for="(item, i) in shuffledItems"
      :key="item.id"
    >
      <Slide>
        <div class="trial-header">
          Aussage {{ i + 1 }} von {{ shuffledItems.length }}
        </div>

        <div class="claim-box">
          <p class="claim-text">„{{ item.claim }}"</p>
        </div>

        <div class="rating-section">
          <p class="rating-question">
            Wie sehr gilt diese Aussage Ihrer Meinung nach als allgemein anerkannt?
          </p>

          <div class="slider-wrap">
            <span class="anchor anchor-left">überhaupt nicht<br />anerkannt</span>
            <input
              v-model.number="ratings[item.id]"
              type="range"
              min="0"
              max="100"
              step="1"
              class="slider"
              @input="sliderTouched[item.id] = true"
            />
            <span class="anchor anchor-right">vollständig<br />anerkannt</span>
          </div>

          <div class="slider-value">
            Ihre Einschätzung: <strong>{{ ratings[item.id] }}</strong>
          </div>
        </div>

        <div class="btn-row">
          <button
            class="next-btn"
            :disabled="!sliderTouched[item.id]"
            @click="recordAndAdvance(item, i)"
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
import { ITEMS } from './stimuli.js';

export default {
  name: 'App',
  data() {
    return {
      shuffledItems: [],
      ratings: {},         // { [item.id]: 0–100 }
      sliderTouched: {},   // { [item.id]: bool }
      trialStartTime: null
    };
  },
  created() {
    this.shuffledItems = _.shuffle([...ITEMS]);
    // Initialise all sliders at 50 (neutral midpoint)
    this.shuffledItems.forEach((item) => {
      this.$set(this.ratings, item.id, 50);
      this.$set(this.sliderTouched, item.id, false);
    });
    this.trialStartTime = Date.now();
  },
  methods: {
    recordAndAdvance(item, index) {
      const rt = Date.now() - this.trialStartTime;
      this.$magpie.addTrialData({
        trial_index: index + 1,
        item_id: item.id,
        topic: item.topic,
        claim: item.claim,
        pc_prop_rating: this.ratings[item.id],
        rt
      });
      this.trialStartTime = Date.now();
      this.$magpie.nextScreen();
    }
  }
};
</script>

<style scoped>
.trial-header {
  color: #888;
  font-size: 0.85em;
  margin-bottom: 1.2em;
  letter-spacing: 0.03em;
}

.claim-box {
  background: #f0f4fa;
  border-left: 4px solid #4a7ec0;
  padding: 1em 1.4em;
  margin-bottom: 1.8em;
  border-radius: 0 6px 6px 0;
  line-height: 1.6;
}

.claim-text {
  margin: 0;
  font-size: 1.1em;
  color: #222;
  font-style: italic;
}

.rating-section {
  margin-bottom: 2em;
}

.rating-question {
  margin-bottom: 1em;
  font-weight: 500;
  line-height: 1.5;
}

.slider-wrap {
  display: flex;
  align-items: center;
  gap: 0.8em;
  margin-bottom: 0.6em;
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
  min-width: 3.5em;
}

.anchor-left {
  text-align: right;
}

.anchor-right {
  text-align: left;
}

.slider-value {
  text-align: center;
  font-size: 1em;
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
