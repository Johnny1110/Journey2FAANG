<script setup>
import { ref, computed, onMounted, watch } from 'vue'
import PassageBlock from './PassageBlock.vue'
import ClozeParagraph from './ClozeParagraph.vue'
import QuestionCard from './QuestionCard.vue'
import { flattenItems, isCorrect, estimateBand } from '../data/index.js'
import { useTimer, formatClock } from '../composables/useTimer.js'
import { saveDraft, clearDraft, loadDraft } from '../composables/useStorage.js'

const props = defineProps({
  week: { type: Object, required: true },
  timed: { type: Boolean, required: true },
})
const emit = defineEmits(['finish', 'quit'])

const responses = ref({})
const items = computed(() => flattenItems(props.week))
const limit = props.timed ? props.week.timeLimitSec : null
const timer = useTimer(limit)

const answered = computed(() => items.value.filter((i) => hasResponse(i.id)).length)
const total = computed(() => items.value.length)
const progressPct = computed(() => (total.value ? (answered.value / total.value) * 100 : 0))
const lowTime = computed(() => timer.remaining.value != null && timer.remaining.value <= 180)

function hasResponse(id) {
  const v = responses.value[id]
  return v != null && String(v).trim() !== ''
}

function update(id, value) {
  responses.value = { ...responses.value, [id]: value }
}

onMounted(() => {
  const draft = loadDraft(props.week.id)
  if (draft && confirm('偵測到上次未完成的作答，要接續嗎？')) {
    responses.value = draft.responses
    timer.elapsed.value = draft.elapsed || 0
  }
  timer.start()
})

watch(
  [responses, timer.elapsed],
  () => {
    saveDraft({
      weekId: props.week.id,
      responses: responses.value,
      elapsed: timer.elapsed.value,
    })
  },
  { deep: true },
)

// Auto-submit the moment the countdown hits zero — same as the real test.
watch(timer.expired, (isUp) => {
  if (isUp) submit(true)
})

function submit(auto = false) {
  if (!auto) {
    const missing = total.value - answered.value
    const msg = missing
      ? `還有 ${missing} 題未作答，確定要交卷嗎？`
      : '確定要交卷嗎？'
    if (!confirm(msg)) return
  }
  timer.stop()

  const results = {}
  let correct = 0
  for (const item of items.value) {
    const ok = isCorrect(item, responses.value[item.id])
    results[item.id] = ok
    if (ok) correct += 1
  }

  clearDraft()
  emit('finish', {
    weekId: props.week.id,
    weekTitle: props.week.title,
    timed: props.timed,
    elapsed: timer.elapsed.value,
    autoSubmitted: auto,
    correct,
    total: total.value,
    band: estimateBand(correct / total.value),
    responses: responses.value,
    results,
    at: new Date().toISOString(),
  })
}

function quit() {
  if (!confirm('離開會保留作答草稿，但不會計分。確定離開？')) return
  timer.stop()
  emit('quit')
}
</script>

<template>
  <div class="exam">
    <header class="bar">
      <div class="bar-inner">
        <button class="quit" @click="quit">← 離開</button>

        <div class="clock" :class="{ low: lowTime, untimed: !timed }">
          <span class="clock-label">{{ timed ? '剩餘' : '已用' }}</span>
          <span class="clock-value">{{
            formatClock(timed ? timer.remaining.value : timer.elapsed.value)
          }}</span>
        </div>

        <div class="progress">
          <div class="progress-text">{{ answered }} / {{ total }}</div>
          <div class="progress-track">
            <div class="progress-fill" :style="{ width: `${progressPct}%` }" />
          </div>
        </div>

        <button class="submit" @click="submit(false)">交卷</button>
      </div>
    </header>

    <main class="sheet">
      <h1 class="week-title">
        {{ week.title }}
        <span class="week-topics">{{ week.topics.join('　·　') }}</span>
      </h1>

      <section v-for="part in week.parts" :key="part.id" class="part">
        <div class="part-head">
          <h2>{{ part.title }}</h2>
          <p v-if="part.instructions" class="instructions">{{ part.instructions }}</p>
        </div>

        <template v-if="part.type === 'cloze'">
          <ClozeParagraph
            v-for="(block, i) in part.blocks"
            :key="i"
            :block="block"
            :responses="responses"
            @update="update"
          />
        </template>

        <template v-else>
          <div v-for="(block, i) in part.blocks" :key="i" class="block">
            <PassageBlock :block="block" />
            <QuestionCard
              v-for="q in block.questions"
              :key="q.id"
              :question="q"
              :response="responses[q.id] ?? null"
              @update="update"
            />
          </div>
        </template>
      </section>

      <div class="foot">
        <button class="submit big" @click="submit(false)">交卷並看結果</button>
      </div>
    </main>
  </div>
</template>

<style scoped>
.bar {
  position: sticky;
  top: 0;
  z-index: 10;
  background: var(--bar);
  border-bottom: 1px solid var(--border);
  backdrop-filter: blur(8px);
}
.bar-inner {
  max-width: 860px;
  margin: 0 auto;
  padding: 0.7rem 1.25rem;
  display: flex;
  align-items: center;
  gap: 1rem;
}
.quit {
  border: none;
  background: none;
  color: var(--muted);
  cursor: pointer;
  font: inherit;
  font-size: 0.88rem;
  padding: 0.3rem 0;
}
.quit:hover {
  color: var(--text);
}
.clock {
  display: flex;
  align-items: baseline;
  gap: 0.4rem;
  padding: 0.25rem 0.7rem;
  border-radius: 7px;
  background: var(--chip);
  font-variant-numeric: tabular-nums;
}
.clock.low {
  background: var(--bad-bg);
  color: var(--bad);
}
.clock-label {
  font-size: 0.72rem;
  color: var(--muted);
}
.clock.low .clock-label {
  color: inherit;
}
.clock-value {
  font-size: 1.05rem;
  font-weight: 700;
}
.progress {
  flex: 1;
  min-width: 0;
}
.progress-text {
  font-size: 0.75rem;
  color: var(--muted);
  font-variant-numeric: tabular-nums;
  margin-bottom: 0.2rem;
}
.progress-track {
  height: 4px;
  border-radius: 2px;
  background: var(--border);
  overflow: hidden;
}
.progress-fill {
  height: 100%;
  background: var(--accent);
  transition: width 0.2s;
}
.submit {
  flex: none;
  padding: 0.45rem 1.1rem;
  border: none;
  border-radius: 7px;
  background: var(--accent);
  color: #fff;
  font-weight: 700;
  cursor: pointer;
  font-size: 0.9rem;
}
.submit:hover {
  filter: brightness(1.08);
}
.submit.big {
  padding: 0.8rem 2.2rem;
  font-size: 1rem;
}
.sheet {
  max-width: 860px;
  margin: 0 auto;
  padding: 2rem 1.25rem 5rem;
}
.week-title {
  font-size: 1.5rem;
  margin: 0 0 2rem;
  display: flex;
  flex-direction: column;
  gap: 0.3rem;
}
.week-topics {
  font-size: 0.88rem;
  font-weight: 400;
  color: var(--muted);
}
.part {
  margin-bottom: 3rem;
}
.part-head {
  margin-bottom: 1.2rem;
  padding-bottom: 0.7rem;
  border-bottom: 2px solid var(--border-strong);
}
.part-head h2 {
  margin: 0;
  font-size: 1.15rem;
}
.instructions {
  margin: 0.4rem 0 0;
  font-size: 0.88rem;
  color: var(--muted);
  line-height: 1.7;
}
.block {
  margin-bottom: 2rem;
}
.foot {
  text-align: center;
  margin-top: 2rem;
}
@media (max-width: 600px) {
  .bar-inner {
    flex-wrap: wrap;
    gap: 0.6rem;
  }
  .progress {
    order: 3;
    flex-basis: 100%;
  }
}
</style>
