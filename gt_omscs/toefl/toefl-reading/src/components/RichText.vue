<script setup>
import { computed } from 'vue'

const props = defineProps({ text: { type: String, required: true } })

// Only **bold** is supported — enough for email headers and the key terms that
// vocabulary questions point at. Tokenising beats v-html: no injection surface.
const tokens = computed(() => {
  const out = []
  const re = /\*\*(.+?)\*\*/g
  let last = 0
  let m
  while ((m = re.exec(props.text)) !== null) {
    if (m.index > last) out.push({ bold: false, value: props.text.slice(last, m.index) })
    out.push({ bold: true, value: m[1] })
    last = m.index + m[0].length
  }
  if (last < props.text.length) out.push({ bold: false, value: props.text.slice(last) })
  return out
})
</script>

<template>
  <span
    ><template v-for="(t, i) in tokens" :key="i"
      ><strong v-if="t.bold">{{ t.value }}</strong
      ><template v-else>{{ t.value }}</template></template
    ></span
  >
</template>
