import * as React from 'react'
import { cn } from 'cn'

function Input({ className, type, onWheel, ...props }: React.ComponentProps<'input'>) {
  return (
    <input
      type={type}
      data-slot="input"
      className={cn(
        'border-input selection:bg-primary selection:text-primary-foreground file:text-foreground placeholder:text-muted-foreground dark:bg-input/30 h-9 w-full min-w-0 rounded-md border bg-transparent px-3 py-1 text-base shadow-xs transition-[color,box-shadow] outline-none file:inline-flex file:h-7 file:border-0 file:bg-transparent file:text-sm file:font-medium disabled:pointer-events-none disabled:cursor-not-allowed disabled:opacity-50 md:text-sm',
        'focus-visible:border-ring focus-visible:ring-ring/50 focus-visible:ring-[3px]',
        'aria-invalid:border-destructive aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40',
        // Hide the native step arrows on a number input (WebKit/Blink + Firefox) — they
        // invite exactly the scroll/trackpad accident this is also guarding against below,
        // and nothing in this app relies on them.
        type === 'number' &&
          '[appearance:textfield] [&::-webkit-inner-spin-button]:appearance-none [&::-webkit-outer-spin-button]:appearance-none',
        className,
      )}
      onWheel={(e) => {
        // A focused number input silently changes value on scroll/trackpad input in
        // Chromium-based browsers — not just visually via the (now-hidden) arrows. Blurring
        // on wheel is the standard fix: the scroll gesture passes through to the page
        // instead of nudging the value.
        if (type === 'number') e.currentTarget.blur()
        onWheel?.(e)
      }}
      {...props}
    />
  )
}

export { Input }
