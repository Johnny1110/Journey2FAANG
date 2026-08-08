<script setup>
import RichText from './RichText.vue'

defineProps({ block: { type: Object, required: true } })
</script>

<template>
  <div class="passage" :class="`style-${block.style || 'academic'}`">
    <h4 class="block-title">{{ block.title }}</h4>
    <p v-for="(para, i) in block.body" :key="i" class="para">
      <RichText :text="para" />
    </p>
  </div>
</template>

<style scoped>
.passage {
  padding: 1.1rem 1.3rem;
  border-radius: 10px;
  background: var(--paper);
  border: 1px solid var(--border);
  margin-bottom: 1rem;
}
.style-email,
.style-notice {
  border-left: 3px solid var(--accent);
}
.block-title {
  margin: 0 0 0.7rem;
  font-size: 0.95rem;
  color: var(--muted);
  letter-spacing: 0.04em;
  text-transform: uppercase;
}
.para {
  margin: 0 0 0.8rem;
  line-height: 1.85;
  font-size: 1.02rem;
}
.para:last-child {
  margin-bottom: 0;
}
.style-academic .para {
  text-align: justify;
}
</style>
