# Native element → shadcn/Radix

The standing rule in this setup: **native interactive elements are never
acceptable in a product surface.** No native date picker, no raw `<select>`, no
browser `<dialog>`, no `confirm()`. They cannot be styled consistently, they
render differently on every OS and browser, and each one is a hole in the single
shared primitive layer the design system depends on.

`scripts/lint_native_elements.py` enforces this and exits non-zero on a hit.
This file is the replacement for each one.

Upstream's own framework adapters cover Vue, Svelte, Angular, Solid, Lit, React
Native, Flutter and Compose — none of them is shadcn, and Radix appears there
only as a crosswalk target. That gap is why this file exists.

## The table

| Native | Replacement | Radix primitive underneath |
| ------ | ----------- | -------------------------- |
| `<select>` (short, known list) | `Select` | `@radix-ui/react-select` |
| `<select>` (long or searchable) | `Combobox` = `Command` inside `Popover` | `react-popover` + `cmdk` |
| `<select multiple>` | `Combobox` with `multiple` + badge list | same |
| `<option>` | `SelectItem` / `CommandItem` | — |
| `<datalist>` | `Combobox` | same |
| `<input type="date">` | `DatePicker` = `Calendar` in a `Popover` | `react-popover` + `react-day-picker` |
| `<input type="datetime-local">` | `DatePicker` + a time field | same |
| `<input type="time">` | custom time field | — |
| `<input type="range">` | `Slider` | `@radix-ui/react-slider` |
| `<input type="checkbox">` | `Checkbox` | `@radix-ui/react-checkbox` |
| `<input type="radio">` | `RadioGroup` | `@radix-ui/react-radio-group` |
| `<input type="file">` | styled trigger delegating to a visually hidden input | — |
| `<input type="color">` | custom picker | — |
| `<dialog>` | `Dialog`, or `AlertDialog` when it is destructive | `@radix-ui/react-dialog` / `react-alert-dialog` |
| `<details>` / `<summary>` | `Accordion` or `Collapsible` | `react-accordion` / `react-collapsible` |
| `<progress>` | `Progress` | `@radix-ui/react-progress` |
| `<meter>` | token-driven meter | — |
| `alert()` | `AlertDialog`, or a `Sonner` toast for non-blocking | — |
| `confirm()` | `AlertDialog` with an explicit destructive action | — |
| `prompt()` | `Dialog` with a real labelled field | — |
| title-attribute tooltip | `Tooltip` | `@radix-ui/react-tooltip` |
| unstyled `<button>` | `Button` with variant + size | `Slot` when `asChild` |

## Select vs Combobox

Decide by cardinality and by whether the user knows the value:

- **≤ 10 options, all visible, user recognises them** → `Select`. Cheaper, no
  search affordance to explain.
- **> 10, or the user types the value from memory** (country, currency, user,
  repo, tag) → `Combobox`. A `Select` with 200 items is a scroll trap.
- **The value may not exist yet** (tags, labels) → `Combobox` with a create row.

## The react-hook-form pitfall

The mistake that costs the most time when migrating off native inputs: Radix
components are **not** native inputs, so `register()` does not reach them. They
need `Controller`.

```tsx
// WRONG — register() never sees a Radix Select; the field stays undefined
<Select {...register("country")}>…</Select>

// RIGHT
<Controller
  name="country"
  control={control}
  render={({ field }) => (
    <Select onValueChange={field.onChange} value={field.value}>
      <SelectTrigger><SelectValue placeholder="Select a country" /></SelectTrigger>
      <SelectContent>{/* SelectItem list */}</SelectContent>
    </Select>
  )}
/>
```

The same applies to `Checkbox` (`onCheckedChange`), `RadioGroup`
(`onValueChange`), `Slider` (`onValueChange`, array) and `Switch`
(`onCheckedChange`).

## What you must not lose in the swap

A native element carries behaviour for free. The replacement has to re-earn it,
and this is where a migration usually regresses:

- **Label association.** `<label htmlFor>` pointing at a Radix trigger's `id`,
  or `aria-labelledby`. Verify with `axe_audit.mjs`.
- **Keyboard.** `Select`: typeahead, Home/End, Esc. `Dialog`: focus trap, Esc,
  focus returned to the trigger. Verify with `verify_keyboard.mjs` and
  `verify_focustrap.mjs`.
- **Form submission.** A Radix `Select` does not submit a value by itself — it
  needs a hidden input or a form library binding.
- **Required/invalid state.** Native validation is gone; wire `aria-invalid`
  and a real error message.
- **Target size.** A custom trigger is often smaller than the native control it
  replaced. `verify_target_size.mjs` — 44×44 CSS px minimum (Fitts's Law).
- **Reduced motion.** Radix animations need a `prefers-reduced-motion` branch.
  `verify_reduced_motion.mjs`.

## Where a native element is still correct

Not every native element is interactive chrome. `<input type="text|email|
password|number|search">`, `<textarea>` and `<form>` stay native — shadcn's own
`Input` and `Textarea` are styled wrappers around exactly those. The rule is
about controls whose *appearance and behaviour* the browser owns, not about
avoiding HTML.

`components/ui/**` is exempt from the linter for the same reason: `ui/select.tsx`
IS the Radix wrapper, and `ui/checkbox.tsx` legitimately renders a real input.
