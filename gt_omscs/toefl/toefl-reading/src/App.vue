<script setup>
import { ref, computed } from 'vue'
import HomeView from './components/HomeView.vue'
import ExamView from './components/ExamView.vue'
import ReviewView from './components/ReviewView.vue'
import { getWeek } from './data/index.js'
import { saveResult } from './composables/useStorage.js'

const view = ref('home')
const activeWeekId = ref(null)
const timed = ref(true)
const result = ref(null)

const activeWeek = computed(() => (activeWeekId.value ? getWeek(activeWeekId.value) : null))

function start(weekId, isTimed) {
  activeWeekId.value = weekId
  timed.value = isTimed
  result.value = null
  view.value = 'exam'
  window.scrollTo(0, 0)
}

function finish(r) {
  saveResult(r)
  result.value = r
  view.value = 'review'
  window.scrollTo(0, 0)
}

function openReview(r) {
  activeWeekId.value = r.weekId
  result.value = r
  view.value = 'review'
  window.scrollTo(0, 0)
}

function home() {
  view.value = 'home'
  window.scrollTo(0, 0)
}

function retry() {
  start(activeWeekId.value, timed.value)
}
</script>

<template>
  <HomeView v-if="view === 'home'" @start="start" @review="openReview" />

  <ExamView
    v-else-if="view === 'exam' && activeWeek"
    :key="`${activeWeekId}-${timed}-${result ? 'r' : 'f'}`"
    :week="activeWeek"
    :timed="timed"
    @finish="finish"
    @quit="home"
  />

  <ReviewView
    v-else-if="view === 'review' && activeWeek && result"
    :week="activeWeek"
    :result="result"
    @home="home"
    @retry="retry"
  />
</template>
