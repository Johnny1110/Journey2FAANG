import { ref, computed, onUnmounted } from 'vue'

/**
 * One timer drives both modes: it always counts elapsed seconds, and only the
 * display and the auto-submit trigger depend on whether a limit was set.
 */
export function useTimer(limitSec) {
  const elapsed = ref(0)
  const running = ref(false)
  let handle = null

  const remaining = computed(() =>
    limitSec ? Math.max(0, limitSec - elapsed.value) : null,
  )
  const expired = computed(() => limitSec != null && elapsed.value >= limitSec)

  function start() {
    if (running.value) return
    running.value = true
    handle = setInterval(() => {
      elapsed.value += 1
      if (expired.value) stop()
    }, 1000)
  }

  function stop() {
    running.value = false
    if (handle) clearInterval(handle)
    handle = null
  }

  onUnmounted(stop)

  return { elapsed, remaining, expired, running, start, stop }
}

export function formatClock(sec) {
  const s = Math.max(0, Math.floor(sec))
  const m = Math.floor(s / 60)
  return `${String(m).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`
}
