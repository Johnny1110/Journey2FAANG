<script setup>
import RichText from './RichText.vue'
import { LETTERS } from '../data/index.js'

const props = defineProps({
  question: { type: Object, required: true },
  response: { type: String, default: null },
  review: { type: Boolean, default: false },
})
defineEmits(['update'])

function optionState(letter) {
  if (!props.review) return props.response === letter ? 'picked' : ''
  if (letter === props.question.answer) return 'correct'
  if (letter === props.response) return 'wrong'
  return ''
}
</script>

<template>
  <div class="q" :class="{ unanswered: !review && !response }">
    <div class="q-head">
      <span class="q-no">{{ question.id }}</span>
      <span class="q-prompt"><RichText :text="question.prompt" /></span>
      <span v-if="review" class="q-mark" :class="response === question.answer ? 'ok' : 'bad'">
        {{ response === question.answer ? '✓' : '✗' }}
      </span>
    </div>

    <ul class="options">
      <li v-for="(opt, i) in question.options" :key="i">
        <label class="option" :class="optionState(LETTERS[i])">
          <input
            type="radio"
            :name="`q${question.id}`"
            :value="LETTERS[i]"
            :checked="response === LETTERS[i]"
            :disabled="review"
            @change="$emit('update', question.id, LETTERS[i])"
          />
          <span class="letter">{{ LETTERS[i] }}</span>
          <span class="text">{{ opt }}</span>
        </label>
      </li>
    </ul>

    <p v-if="review && question.explanation" class="explain">
      <span class="explain-tag">解析</span>{{ question.explanation }}
    </p>
  </div>
</template>

<style scoped>
.q {
  padding: 1rem 1.1rem;
  border: 1px solid var(--border);
  border-radius: 10px;
  background: var(--card);
  margin-bottom: 0.9rem;
}
.q.unanswered {
  border-left: 3px solid var(--warn);
}
.q-head {
  display: flex;
  gap: 0.6rem;
  align-items: flex-start;
  margin-bottom: 0.75rem;
}
.q-no {
  flex: none;
  min-width: 1.9rem;
  height: 1.9rem;
  display: grid;
  place-items: center;
  border-radius: 6px;
  background: var(--chip);
  font-size: 0.82rem;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
}
.q-prompt {
  flex: 1;
  font-weight: 600;
  line-height: 1.5;
}
.q-mark {
  flex: none;
  font-weight: 700;
  font-size: 1.1rem;
}
.q-mark.ok {
  color: var(--ok);
}
.q-mark.bad {
  color: var(--bad);
}
.options {
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  gap: 0.4rem;
}
.option {
  display: flex;
  gap: 0.6rem;
  align-items: flex-start;
  padding: 0.55rem 0.7rem;
  border: 1px solid var(--border);
  border-radius: 8px;
  cursor: pointer;
  line-height: 1.5;
  transition: background 0.12s, border-color 0.12s;
}
.option:hover {
  border-color: var(--border-strong);
}
.option input {
  display: none;
}
.option .letter {
  flex: none;
  font-weight: 700;
  color: var(--muted);
  width: 1.1rem;
}
.option.picked {
  border-color: var(--accent);
  background: var(--accent-soft);
}
.option.picked .letter {
  color: var(--accent);
}
.option.correct {
  border-color: var(--ok);
  background: var(--ok-bg);
}
.option.correct .letter {
  color: var(--ok);
}
.option.wrong {
  border-color: var(--bad);
  background: var(--bad-bg);
}
.option.wrong .letter {
  color: var(--bad);
}
.option:has(input:disabled) {
  cursor: default;
}
.explain {
  margin: 0.85rem 0 0;
  padding: 0.7rem 0.85rem;
  background: var(--chip);
  border-radius: 8px;
  font-size: 0.92rem;
  line-height: 1.75;
  color: var(--text-soft);
}
.explain-tag {
  display: inline-block;
  margin-right: 0.5rem;
  padding: 0.05rem 0.4rem;
  border-radius: 4px;
  background: var(--accent);
  color: #fff;
  font-size: 0.72rem;
  font-weight: 700;
  vertical-align: 1px;
}
</style>
