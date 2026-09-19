import { useEffect, useRef } from 'react'

const IDLE_TIMEOUT_MS = 30 * 60 * 1000
const ACTIVITY_EVENTS = ['mousedown', 'keydown', 'scroll', 'touchstart'] as const

/** Calls `onIdle` after 30 minutes with no mouse/keyboard/scroll/touch activity. */
export function useIdleTimeout(onIdle: () => void) {
  const timerRef = useRef<ReturnType<typeof setTimeout> | undefined>(undefined)

  useEffect(() => {
    function resetTimer() {
      if (timerRef.current) clearTimeout(timerRef.current)
      timerRef.current = setTimeout(onIdle, IDLE_TIMEOUT_MS)
    }

    resetTimer()
    for (const event of ACTIVITY_EVENTS) {
      window.addEventListener(event, resetTimer)
    }

    return () => {
      if (timerRef.current) clearTimeout(timerRef.current)
      for (const event of ACTIVITY_EVENTS) {
        window.removeEventListener(event, resetTimer)
      }
    }
  }, [onIdle])
}
