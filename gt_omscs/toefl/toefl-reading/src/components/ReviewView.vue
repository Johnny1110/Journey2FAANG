<script setup>
import { ref, computed } from 'vue'
import PassageBlock from './PassageBlock.vue'
import ClozeParagraph from './ClozeParagraph.vue'
import QuestionCard from './QuestionCard.vue'
import { flattenItems } from '../data/index.js'
import { formatClock } from '../composables/useTimer.js'

const props = defineProps({
  week: { type: Object, required: true },
  result: { type: Object, required: true },
})
const emit = defineEmits(['home', 'retry'])

const onlyWrong = ref(false)
const items = computed(() => flattenItems(props.week))
const pct = computed(() => Math.round((props.result.correct / props.result.total) * 100))

const byPart = computed(() =>
  props.week.parts.map((part) => {
    const partItems = items.value.filter((i) => i.partId === part.id)
    const correct = partItems.filter((i) => props.result.results[i.id]).length
    return { title: part.title, correct, total: partItems.length }
  }),
)

const wrongIds = computed(() =>
  items.value.filter((i) => !props.result.results[i.id]).map((i) => i.id),
)

function visibleQuestions(block) {
  if (!onlyWrong.value) return block.questions
  return block.questions.filter((q) => !props.result.results[q.id])
}

function blockHasWrong(block) {
  if (block.blanks) return block.blanks.some((b) => !props.result.results[b.id])
  return block.questions.some((q) => !props.result.results[q.id])
}

function partHasWrong(part) {
  return part.blocks.some(blockHasWrong)
}
</script>

<template>
  <div class="review">
    <header class="summary">
      <div class="summary-inner">
        <button class="back" @click="emit('home')">← 回到首頁</button>

        <div class="score-row">
          <div class="score-main">
            <div class="score-big">
              {{ result.correct }}<span class="score-total">/{{ result.total }}</span>
            </div>
            <div class="score-sub">{{ pct }}% 正確</div>
          </div>
          <div class="stat">
            <span class="stat-label">估計 Band</span>
            <span class="stat-value">{{ result.band }}</span>
          </div>
          <div class="stat">
            <span class="stat-label">用時</span>
            <span class="stat-value">{{ formatClock(result.elapsed) }}</span>
            <span class="stat-note">{{ result.timed ? '計時模式' : '不計時' }}</span>
          </div>
        </div>

        <p v-if="result.autoSubmitted" class="auto-note">
          ⏱ 時間到，系統自動交卷。未作答的題目一律計為錯誤。
        </p>

        <ul class="part-scores">
          <li v-for="p in byPart" :key="p.title">
            <span class="p-title">{{ p.title }}</span>
            <span class="p-score">{{ p.correct }}/{{ p.total }}</span>
            <span class="p-bar">
              <span class="p-fill" :style="{ width: `${(p.correct / p.total) * 100}%` }" />
            </span>
          </li>
        </ul>

        <div class="actions">
          <label class="filter">
            <input v-model="onlyWrong" type="checkbox" />
            只看錯的（{{ wrongIds.length }} 題）
          </label>
          <button class="retry" @click="emit('retry')">再練一次</button>
        </div>
      </div>
    </header>

    <main class="sheet">
      <p v-if="onlyWrong && !wrongIds.length" class="perfect">
        全對，沒有可以復盤的題目。
      </p>

      <section
        v-for="part in week.parts"
        v-show="!onlyWrong || partHasWrong(part)"
        :key="part.id"
        class="part"
      >
        <div class="part-head">
          <h2>{{ part.title }}</h2>
        </div>

        <template v-if="part.type === 'cloze'">
          <div
            v-for="(block, i) in part.blocks"
            :key="i"
            v-show="!onlyWrong || blockHasWrong(block)"
          >
            <ClozeParagraph
              :block="block"
              :responses="result.responses"
              :results="result.results"
              review
            />
            <ul class="blank-explains">
              <li
                v-for="b in block.blanks.filter(
                  (b) => !onlyWrong || !result.results[b.id],
                )"
                :key="b.id"
                :class="{ wrong: !result.results[b.id] }"
              >
                <span class="b-no">{{ b.id }}</span>
                <span class="b-ans">{{ b.answer }}</span>
                <span class="b-exp">{{ b.explanation }}</span>
              </li>
            </ul>
          </div>
        </template>

        <template v-else>
          <div
            v-for="(block, i) in part.blocks"
            :key="i"
            v-show="!onlyWrong || blockHasWrong(block)"
            class="block"
          >
            <PassageBlock :block="block" />
            <QuestionCard
              v-for="q in visibleQuestions(block)"
              :key="q.id"
              :question="q"
              :response="result.responses[q.id] ?? null"
              review
            />
          </div>
        </template>
      </section>
    </main>
  </div>
</template>

<style scoped>
.summary {
  border-bottom: 1px solid var(--border);
  background: var(--card);
}
.summary-inner {
  max-width: 860px;
  margin: 0 auto;
  padding: 1.5rem 1.25rem 1.2rem;
}
.back {
  border: none;
  background: none;
  color: var(--muted);
  cursor: pointer;
  font: inherit;
  font-size: 0.88rem;
  padding: 0 0 1rem;
}
.back:hover {
  color: var(--text);
}
.score-row {
  display: flex;
  align-items: flex-end;
  gap: 2.5rem;
  flex-wrap: wrap;
}
.score-big {
  font-size: 3rem;
  font-weight: 800;
  line-height: 1;
  letter-spacing: -0.03em;
  font-variant-numeric: tabular-nums;
}
.score-total {
  font-size: 1.5rem;
  font-weight: 600;
  color: var(--muted);
}
.score-sub {
  margin-top: 0.3rem;
  color: var(--muted);
  font-size: 0.9rem;
}
.stat {
  display: flex;
  flex-direction: column;
  gap: 0.15rem;
}
.stat-label {
  font-size: 0.75rem;
  color: var(--muted);
  letter-spacing: 0.06em;
  text-transform: uppercase;
}
.stat-value {
  font-size: 1.5rem;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
}
.stat-note {
  font-size: 0.75rem;
  color: var(--muted);
}
.auto-note {
  margin: 1rem 0 0;
  padding: 0.6rem 0.85rem;
  border-radius: 8px;
  background: var(--warn-bg);
  color: var(--warn);
  font-size: 0.88rem;
}
.part-scores {
  list-style: none;
  margin: 1.4rem 0 0;
  padding: 0;
  display: grid;
  gap: 0.5rem;
}
.part-scores li {
  display: grid;
  grid-template-columns: 1fr auto 120px;
  align-items: center;
  gap: 0.8rem;
  font-size: 0.86rem;
}
.p-score {
  font-variant-numeric: tabular-nums;
  font-weight: 700;
}
.p-bar {
  height: 5px;
  border-radius: 3px;
  background: var(--border);
  overflow: hidden;
}
.p-fill {
  display: block;
  height: 100%;
  background: var(--accent);
}
.actions {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  margin-top: 1.4rem;
  padding-top: 1.1rem;
  border-top: 1px solid var(--border);
  flex-wrap: wrap;
}
.filter {
  display: flex;
  align-items: center;
  gap: 0.45rem;
  font-size: 0.9rem;
  cursor: pointer;
}
.retry {
  padding: 0.5rem 1.2rem;
  border: 1px solid var(--accent);
  border-radius: 7px;
  background: transparent;
  color: var(--accent);
  font-weight: 700;
  cursor: pointer;
  font-size: 0.9rem;
}
.retry:hover {
  background: var(--accent-soft);
}
.sheet {
  max-width: 860px;
  margin: 0 auto;
  padding: 2rem 1.25rem 5rem;
}
.part {
  margin-bottom: 2rem;
}
.part-head {
  margin: 0 0 1.2rem;
  padding-bottom: 0.7rem;
  border-bottom: 2px solid var(--border-strong);
}
.part-head h2 {
  margin: 0;
  font-size: 1.15rem;
}
.block {
  margin-bottom: 2rem;
}
.blank-explains {
  list-style: none;
  margin: 0 0 2rem;
  padding: 0;
  display: grid;
  gap: 0.35rem;
}
.blank-explains li {
  display: grid;
  grid-template-columns: 1.8rem 8rem 1fr;
  gap: 0.7rem;
  align-items: baseline;
  padding: 0.5rem 0.7rem;
  border-radius: 7px;
  background: var(--chip);
  font-size: 0.88rem;
  line-height: 1.65;
}
.blank-explains li.wrong {
  background: var(--bad-bg);
}
.b-no {
  color: var(--muted);
  font-variant-numeric: tabular-nums;
  font-size: 0.8rem;
}
.b-ans {
  font-weight: 700;
  color: var(--ok);
}
.b-exp {
  color: var(--text-soft);
}
.perfect {
  text-align: center;
  color: var(--muted);
  padding: 3rem 0;
}
@media (max-width: 600px) {
  .score-row {
    gap: 1.5rem;
  }
  .part-scores li {
    grid-template-columns: 1fr auto;
  }
  .p-bar {
    display: none;
  }
  .blank-explains li {
    grid-template-columns: 1.8rem 1fr;
  }
  .b-exp {
    grid-column: 2;
  }
}
</style>
