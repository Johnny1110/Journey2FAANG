<script setup>
import { computed } from 'vue'

const props = defineProps({
  block: { type: Object, required: true },
  responses: { type: Object, required: true },
  review: { type: Boolean, default: false },
  results: { type: Object, default: () => ({}) },
})
const emit = defineEmits(['update'])

const blankById = computed(() =>
  Object.fromEntries(props.block.blanks.map((b) => [b.id, b])),
)

// Split "text {{1}} text" into alternating text / blank segments.
const segments = computed(() => {
  const out = []
  const re = /\{\{(\d+)\}\}/g
  let last = 0
  let m
  while ((m = re.exec(props.block.template)) !== null) {
    if (m.index > last) {
      out.push({ type: 'text', value: props.block.template.slice(last, m.index) })
    }
    out.push({ type: 'blank', blank: blankById.value[Number(m[1])] })
    last = m.index + m[0].length
  }
  if (last < props.block.template.length) {
    out.push({ type: 'text', value: props.block.template.slice(last) })
  }
  return out
})

function stateOf(id) {
  if (!props.review) return ''
  return props.results[id] ? 'ok' : 'bad'
}
</script>

<template>
  <div class="cloze">
    <h4 class="block-title">{{ block.title }}</h4>
    <p class="cloze-body">
      <template v-for="(seg, i) in segments" :key="i">
        <template v-if="seg.type === 'text'">{{ seg.value }}</template>
        <span v-else class="blank-wrap" :class="stateOf(seg.blank.id)">
          <span class="blank-no">{{ seg.blank.id }}</span>
          <span class="prefix">{{ seg.blank.prefix }}</span>
          <input
            v-if="!review"
            class="blank-input"
            type="text"
            autocomplete="off"
            autocapitalize="off"
            spellcheck="false"
            :size="Math.max(seg.blank.missing, 4)"
            :value="responses[seg.blank.id] ?? ''"
            :placeholder="'_'.repeat(seg.blank.missing)"
            @input="emit('update', seg.blank.id, $event.target.value)"
          />
          <span v-else class="blank-review">
            <span class="mine" :class="stateOf(seg.blank.id)">{{
              responses[seg.blank.id] || '（未作答）'
            }}</span>
            <span v-if="!results[seg.blank.id]" class="truth">{{ seg.blank.answer }}</span>
          </span>
        </span>
      </template>
    </p>
  </div>
</template>

<style scoped>
.block-title {
  margin: 0 0 0.6rem;
  font-size: 0.95rem;
  color: var(--muted);
  letter-spacing: 0.04em;
  text-transform: uppercase;
}
.cloze-body {
  line-height: 2.6;
  font-size: 1.02rem;
  margin: 0;
}
.blank-wrap {
  display: inline-flex;
  align-items: baseline;
  gap: 1px;
  padding: 0.1rem 0.35rem;
  border-radius: 6px;
  background: var(--blank-bg);
  white-space: nowrap;
}
.blank-wrap.ok {
  background: var(--ok-bg);
}
.blank-wrap.bad {
  background: var(--bad-bg);
}
.blank-no {
  font-size: 0.68rem;
  color: var(--muted);
  margin-right: 0.2rem;
  font-variant-numeric: tabular-nums;
}
.prefix {
  font-weight: 600;
}
.blank-input {
  font: inherit;
  font-weight: 600;
  color: var(--accent);
  border: none;
  border-bottom: 2px solid var(--border-strong);
  background: transparent;
  padding: 0 2px;
  min-width: 3.5rem;
  outline: none;
}
.blank-input:focus {
  border-bottom-color: var(--accent);
}
.blank-input::placeholder {
  color: var(--muted);
  letter-spacing: 1px;
}
.mine {
  font-weight: 600;
}
.mine.bad {
  text-decoration: line-through;
  color: var(--bad);
  font-weight: 500;
}
.truth {
  margin-left: 0.4rem;
  font-weight: 700;
  color: var(--ok);
}
</style>
