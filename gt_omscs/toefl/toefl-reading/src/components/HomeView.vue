<script setup>
import { ref, computed } from 'vue'
import { weeks, flattenItems } from '../data/index.js'
import { bestFor, attemptsFor, loadResults, clearResults, loadDraft } from '../composables/useStorage.js'
import { formatClock } from '../composables/useTimer.js'

const emit = defineEmits(['start', 'review'])

const timed = ref(true)
const historyOpen = ref(false)
const results = ref(loadResults())

const cards = computed(() =>
  weeks.map((w) => ({
    week: w,
    total: flattenItems(w).length,
    best: bestFor(w.id),
    attempts: attemptsFor(w.id),
    draft: loadDraft(w.id),
  })),
)

function refresh() {
  results.value = loadResults()
}

function onClearHistory() {
  if (!confirm('確定要清除所有作答紀錄嗎？此動作無法復原。')) return
  clearResults()
  refresh()
}

function pct(r) {
  return Math.round((r.correct / r.total) * 100)
}
</script>

<template>
  <div class="home">
    <header class="hero">
      <p class="eyebrow">GT OMSCS · TOEFL 100</p>
      <h1>Reading Practice</h1>
      <p class="sub">
        2026 新制題型模擬。目標 band 5.0–5.5（舊制 100–113）。
      </p>
    </header>

    <section class="mode">
      <h2>練習模式</h2>
      <div class="mode-toggle">
        <button :class="{ active: timed }" @click="timed = true">
          <span class="mode-name">計時模擬</span>
          <span class="mode-desc">27 分鐘倒數，時間到自動交卷</span>
        </button>
        <button :class="{ active: !timed }" @click="timed = false">
          <span class="mode-name">不計時練習</span>
          <span class="mode-desc">只記錄用時，慢慢想</span>
        </button>
      </div>
    </section>

    <section class="weeks">
      <h2>選擇週次</h2>
      <p v-if="!cards.length" class="empty">
        還沒有題目。用 <code>/toefl init reading</code> 產生第一週。
      </p>
      <ul v-else class="week-list">
        <li v-for="c in cards" :key="c.week.id" class="week-card">
          <div class="week-main">
            <div class="week-head">
              <h3>{{ c.week.title }}</h3>
              <span class="date">{{ c.week.date }}</span>
              <span v-if="c.draft" class="draft-tag">有未完成作答</span>
            </div>
            <p class="topics">{{ c.week.topics.join('　·　') }}</p>
            <p class="meta">
              {{ c.total }} 題
              <template v-if="c.attempts">
                · 已練 {{ c.attempts }} 次 · 最佳
                <strong>{{ c.best.correct }}/{{ c.best.total }}</strong>
                （band {{ c.best.band }}）
              </template>
            </p>
          </div>
          <button class="start" @click="emit('start', c.week.id, timed)">
            {{ c.attempts ? '再練一次' : '開始' }}
          </button>
        </li>
      </ul>
    </section>

    <section class="history">
      <button class="link" @click="historyOpen = !historyOpen; refresh()">
        {{ historyOpen ? '▾' : '▸' }} 作答紀錄（{{ results.length }}）
      </button>
      <div v-if="historyOpen" class="history-body">
        <p v-if="!results.length" class="empty">還沒有紀錄。</p>
        <template v-else>
          <table>
            <thead>
              <tr>
                <th>日期</th>
                <th>週次</th>
                <th>模式</th>
                <th>用時</th>
                <th>得分</th>
                <th>Band</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="r in results" :key="r.at">
                <td>{{ new Date(r.at).toLocaleString('zh-TW', { hour12: false }) }}</td>
                <td>{{ r.weekTitle }}</td>
                <td>{{ r.timed ? '計時' : '不計時' }}</td>
                <td>{{ formatClock(r.elapsed) }}</td>
                <td>
                  <strong>{{ r.correct }}/{{ r.total }}</strong>
                  <span class="dim"> ({{ pct(r) }}%)</span>
                </td>
                <td>{{ r.band }}</td>
                <td>
                  <button class="link small" @click="emit('review', r)">復盤</button>
                </td>
              </tr>
            </tbody>
          </table>
          <button class="link danger" @click="onClearHistory">清除全部紀錄</button>
        </template>
      </div>
    </section>
  </div>
</template>

<style scoped>
.home {
  max-width: 820px;
  margin: 0 auto;
  padding: 3rem 1.25rem 5rem;
}
.hero {
  margin-bottom: 2.5rem;
}
.eyebrow {
  margin: 0 0 0.4rem;
  font-size: 0.78rem;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--accent);
  font-weight: 700;
}
.hero h1 {
  margin: 0 0 0.5rem;
  font-size: 2.1rem;
  letter-spacing: -0.02em;
}
.sub {
  margin: 0;
  color: var(--muted);
}
h2 {
  font-size: 0.82rem;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  color: var(--muted);
  margin: 0 0 0.8rem;
}
section {
  margin-bottom: 2.2rem;
}
.mode-toggle {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.7rem;
}
.mode-toggle button {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
  align-items: flex-start;
  padding: 0.9rem 1rem;
  border: 1px solid var(--border);
  border-radius: 10px;
  background: var(--card);
  cursor: pointer;
  text-align: left;
  transition: border-color 0.12s, background 0.12s;
}
.mode-toggle button:hover {
  border-color: var(--border-strong);
}
.mode-toggle button.active {
  border-color: var(--accent);
  background: var(--accent-soft);
}
.mode-name {
  font-weight: 700;
}
.mode-desc {
  font-size: 0.84rem;
  color: var(--muted);
}
.week-list {
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  gap: 0.7rem;
}
.week-card {
  display: flex;
  gap: 1rem;
  align-items: center;
  padding: 1.1rem 1.2rem;
  border: 1px solid var(--border);
  border-radius: 10px;
  background: var(--card);
}
.week-main {
  flex: 1;
  min-width: 0;
}
.week-head {
  display: flex;
  align-items: baseline;
  gap: 0.6rem;
  flex-wrap: wrap;
}
.week-head h3 {
  margin: 0;
  font-size: 1.1rem;
}
.date,
.meta {
  font-size: 0.82rem;
  color: var(--muted);
}
.draft-tag {
  font-size: 0.72rem;
  padding: 0.1rem 0.45rem;
  border-radius: 4px;
  background: var(--warn-bg);
  color: var(--warn);
  font-weight: 700;
}
.topics {
  margin: 0.35rem 0 0.3rem;
  font-size: 0.92rem;
}
.meta {
  margin: 0;
}
.start {
  flex: none;
  padding: 0.6rem 1.3rem;
  border: none;
  border-radius: 8px;
  background: var(--accent);
  color: #fff;
  font-weight: 700;
  font-size: 0.95rem;
  cursor: pointer;
}
.start:hover {
  filter: brightness(1.08);
}
.empty {
  color: var(--muted);
  font-size: 0.92rem;
}
.link {
  border: none;
  background: none;
  color: var(--accent);
  cursor: pointer;
  font: inherit;
  font-size: 0.88rem;
  padding: 0;
}
.link.small {
  font-size: 0.82rem;
}
.link.danger {
  color: var(--bad);
  margin-top: 0.8rem;
}
.history-body {
  margin-top: 0.8rem;
}
table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.85rem;
}
th,
td {
  text-align: left;
  padding: 0.45rem 0.5rem;
  border-bottom: 1px solid var(--border);
}
th {
  color: var(--muted);
  font-weight: 600;
  font-size: 0.78rem;
}
.dim {
  color: var(--muted);
}
code {
  background: var(--chip);
  padding: 0.1rem 0.35rem;
  border-radius: 4px;
  font-size: 0.88em;
}
@media (max-width: 600px) {
  .mode-toggle {
    grid-template-columns: 1fr;
  }
  .week-card {
    flex-direction: column;
    align-items: stretch;
  }
}
</style>
