---
name: laws-of-ux
description: >
  The 30 Laws of UX (lawsofux.com, Jon Yablonski) as binding design constraints.
  Step 0 of the design pipeline: resolve which laws govern the surface BEFORE art
  direction, because they cap what the direction is allowed to propose — how many
  options a menu may hold, how small a tap target may be, whether a novel pattern
  is permitted at all. Use when designing, building, reviewing or auditing any UI
  surface: navigation, forms, tables, modals, onboarding, empty states, pricing,
  checkout, dashboards, settings, error states, loading states, motion.
  Also use to justify or reject a UI decision with a named principle instead of taste.
---

# Laws of UX

30 principles from psychology and human-factors research, catalogued by Jon
Yablonski at <https://lawsofux.com>. This skill treats them as **constraints on
the solution space**, not as a checklist run after the fact.

## Why this runs FIRST

A law discovered after the direction exists does not get applied — it gets
rationalised around. Hick's Law caps how many top-level items the navigation may
carry; Fitts's Law sets the floor on target size and edge placement; Jakob's Law
decides whether a novel pattern is allowed at all. Those are inputs to art
direction, not a review pass over it. Run this before `frontend-design`.

## Protocol

1. **Name the surface.** Nav, form, list, checkout, onboarding, empty state, …
2. **Resolve the governing laws** from the routing table below. Three to six is
   normal; more than eight means the surface is doing too many jobs (Occam's Razor).
3. **Convert each law into a hard number or a hard rule** for THIS surface —
   "max 5 filter chips", "44×44 CSS px minimum", "progress bar starts at 20%".
   A law stated without its consequence is decoration.
4. **Check against `.agents/DESIGN.md`.** It is the project's source of truth. If
   a law contradicts a recorded decision, surface the conflict; do not silently
   pick a side.
5. **Emit step 0 of the `[design-pipeline]` checklist** naming the specific laws
   and what each one dictates. The gate hook denies UI edits without it.

```
0. laws-of-ux        → laws: Hick (5 nav items max), Fitts (44px targets, bottom-edge CTA),
                       Von Restorff (single accent on primary action), Doherty (<400ms feedback)
```

Never write "laws-of-ux → applied" or echo the placeholder. Name the laws and the
numbers they produce.

## Routing table — surface → governing laws

| Surface | Laws that bind it |
| ------- | ----------------- |
| Navigation, menus, tabs | Hick's Law, Miller's Law, Serial Position Effect, Jakob's Law, Law of Proximity |
| Forms, inputs | Postel's Law, Chunking, Parkinson's Law, Working Memory, Doherty Threshold, Tesler's Law |
| Lists, tables, search results | Chunking, Law of Proximity, Law of Common Region, Selective Attention, Von Restorff Effect |
| Pricing, plan selection | Choice Overload, Hick's Law, Von Restorff Effect, Serial Position Effect |
| Checkout, multi-step flows | Goal-Gradient Effect, Zeigarnik Effect, Chunking, Peak-End Rule, Jakob's Law |
| Onboarding, first run | Paradox of the Active User, Progressive disclosure via Hick's Law, Cognitive Load, Flow |
| Dashboards, data views | Pareto Principle, Selective Attention, Miller's Law, Law of Common Region, Law of Similarity |
| Empty states | Zeigarnik Effect, Paradox of the Active User, Von Restorff Effect |
| Error states, validation | Postel's Law, Peak-End Rule, Cognitive Load, Tesler's Law |
| Loading, async, optimistic UI | Doherty Threshold, Goal-Gradient Effect, Flow, Parkinson's Law |
| Visual grouping, layout, spacing | Law of Proximity, Law of Common Region, Law of Similarity, Law of Uniform Connectedness, Law of Prägnanz |
| Buttons, tap targets, mobile | Fitts's Law, Von Restorff Effect, Jakob's Law |
| Copy, labels, microcopy | Jakob's Law, Mental Model, Cognitive Load, Occam's Razor |
| Motion, micro-interactions | Doherty Threshold, Von Restorff Effect, Flow, Selective Attention |
| Redesigns, migrations | Jakob's Law, Mental Model, Peak-End Rule, Cognitive Bias |

## The 30 laws — definition and what each one dictates

Definitions are verbatim from lawsofux.com. The **Dictates** line is the
operational consequence: what it actually forces you to do or forbid.

### Heuristics

**Aesthetic-Usability Effect** — *Users often perceive aesthetically pleasing design as design that's more usable.*
Dictates: polish is functional, not decoration — it buys tolerance for minor
friction. But it also masks real usability defects, so never let a beautiful
prototype substitute for a usability test, and never read positive aesthetic
feedback as evidence the flow works.

**Doherty Threshold** — *Productivity soars when a computer and its users interact at a pace (<400ms) that ensures that neither has to wait on the other.*
Dictates: every interaction acknowledges within **400 ms** — a state change, a
skeleton, a spinner, an optimistic update. Beyond 400 ms show a progress
indicator; beyond ~1 s show progress with an estimate. Perceived performance
counts: skeleton screens and optimistic UI satisfy this where real speed cannot.
A deliberate delay can raise perceived value and trust for work that looks
instant but shouldn't (security checks, "analysing").

**Fitts's Law** — *The time to acquire a target is a function of the distance to and size of the target.*
Dictates: interactive targets ≥ **44×44 CSS px** (≥48 dp Android, ≥44 pt iOS),
with ≥8 px between adjacent targets. Put primary actions near the pointer's
likely origin or on a screen edge — edges and corners are infinitely deep
targets. On mobile, primary actions go in the thumb zone (bottom), destructive
ones out of it. Never place a destructive action adjacent to a frequent one.

**Goal-Gradient Effect** — *The tendency to approach a goal increases with proximity to the goal.*
Dictates: show progress in any flow over two steps, and **endow the progress** —
start the bar at 20 %, or give the loyalty card two stamps free. Motivation rises
near the finish, so put the highest-friction step early, not last.

**Hick's Law** — *The time it takes to make a decision increases with the number and complexity of choices.*
Dictates: cap simultaneous choices. Navigation ≤ 7 top-level items, ideally 5.
Highlight one recommended option to collapse the decision. Break complex tasks
into steps. Use progressive onboarding rather than a full feature tour. The
counter-limit matters: do not simplify to abstraction — three vague categories
are worse than eight concrete ones.

**Jakob's Law** — *Users spend most of their time on other sites. This means that users prefer your site to work the same way as all the other sites they already know.*
Dictates: use the convention unless you can state what the novel pattern buys.
Logo top-left links home. Cart top-right. Search is a magnifier with a field.
Underlined coloured text is a link. Form submit is bottom-right of the form. When
you must change something familiar, let users opt into the old version for a
period rather than forcing the switch.

**Law of Prägnanz** — *People will perceive and interpret ambiguous or complex images as the simplest form possible, because it is the interpretation that requires the least cognitive effort of us.*
Dictates: prefer simple, regular, symmetrical forms for icons, logos, charts and
illustrations. Simple figures are processed faster and remembered better. If a
shape needs a caption to be read, it is too complex.

**Occam's Razor** — *Among competing hypotheses that predict equally well, the one with the fewest assumptions should be selected.*
Dictates: remove every element that can be removed without losing function, then
stop only when nothing else can go. Best way to reduce complexity is not to add
it. Applies to options, fields, steps, colours, weights and breakpoints alike.

**Pareto Principle** — *The Pareto principle states that, for many events, roughly 80% of the effects come from 20% of the causes.*
Dictates: identify the ~20 % of features carrying ~80 % of usage and give them
the hierarchy, polish and performance budget. Everything else goes behind
disclosure. Optimise the common path, not the exhaustive one.

**Parkinson's Law** — *Any task will inflate until all of the available time is spent.*
Dictates: cap the time a task appears to need. Autofill, saved payment methods,
smart defaults, address lookup, paste-friendly OTP fields. Finishing faster than
the user expected is itself a positive experience.

**Peak-End Rule** — *People judge an experience largely based on how they felt at its peak and at its end, rather than the total sum or average of every moment of the experience.*
Dictates: find the emotional peak and the last moment of each flow and invest
there — the confirmation screen, the success state, the first successful action.
Negative peaks are remembered more vividly than positive ones, so an error state
deserves more design care than a success state.

**Postel's Law** — *Be liberal in what you accept, and conservative in what you send.*
Dictates: accept any reasonable input shape and normalise it yourself — phone
numbers with spaces or dashes, cards with or without groups, dates in several
orders, trailing whitespace, mixed case emails. Never reject what you could
parse. Output strictly: one clear format, one clear message, clear boundaries
stated before the error rather than after.

**Selective Attention** — *The process of focusing our attention only to a subset of stimuli in an environment — usually those related to our goals.*
Dictates: guide attention to one thing per view. Do not style content to look
like advertising, and do not place content in ad-shaped slots or ad-adjacent
positions — banner blindness will erase it. Avoid simultaneous competing changes;
change blindness will hide the one that mattered. Announce important changes
where attention already is, not where there is room.

**Serial Position Effect** — *Users have a propensity to best remember the first and last items in a series.*
Dictates: put the most important items first and last; bury the least important
in the middle. In navigation, the primary action and the account/CTA belong at
the extremes. In a list of options, the anchor and the recommendation take
position one and last.

**Tesler's Law** (Conservation of Complexity) — *For any system there is a certain amount of complexity which cannot be reduced.*
Dictates: irreducible complexity is absorbed by the system or dumped on the user
— choose the system. Infer the country from the phone number, derive tax from the
address, parse the card type from the digits. Never build for an idealised
rational user. Where complexity truly cannot be absorbed, make guidance available
in context, at the moment of use.

**Von Restorff Effect** (Isolation Effect) — *When multiple similar objects are present, the one that differs from the rest is most likely to be remembered.*
Dictates: exactly one primary emphasis per view. Two primary buttons means
neither is primary. Emphasis must not rely on colour alone — pair it with weight,
size, position or an icon so colour-vision-deficient and low-vision users get the
same signal. Respect `prefers-reduced-motion` when emphasis is animated. Overused
emphasis reads as advertising and is filtered out (see Selective Attention).

**Zeigarnik Effect** — *People remember uncompleted or interrupted tasks better than completed tasks.*
Dictates: show what is unfinished — incomplete profile meters, partially visible
content below the fold, draft badges, "3 of 5 steps". Signifiers of more content
invite discovery. The flip side: an unresolved task left visible indefinitely
becomes anxiety, so always pair it with a way to finish or dismiss it.

### Gestalt principles

**Law of Common Region** — *Elements tend to be perceived into groups if they are sharing an area with a clearly defined boundary.*
Dictates: a border or a background creates a group with no spacing changes at
all, and it beats proximity when the two conflict. Use it for cards, toolbars,
grouped form sections, table row banding.

**Law of Proximity** — *Objects that are near, or proximate to each other, tend to be grouped together.*
Dictates: spacing is semantics. Label sits closer to its input than to the
previous field; help text closer to its control than to the next. Whitespace
between groups must exceed whitespace inside them — if it does not, the grouping
reads backwards regardless of what the markup says.

**Law of Similarity** — *The human eye tends to perceive similar elements as a complete picture, shape, or group, even if those elements are separated.*
Dictates: same appearance implies same behaviour, and the reverse is a bug — do
not style a non-interactive element like a button. Links and navigation must be
visually distinct from body text. Keep one shape language per role across the
product.

**Law of Uniform Connectedness** — *Elements that are visually connected are perceived as more related than elements with no connection.*
Dictates: explicit connectors — lines, frames, shared backgrounds, arrows — beat
proximity and similarity when you need an unambiguous relationship. Use for
steppers, timelines, nested menus, org charts, and to tie a control to the thing
it controls.

### Cognitive principles

**Choice Overload** — *The tendency for people to get overwhelmed when they are presented with a large number of options, often used interchangeably with the term paradox of choice.*
Dictates: when comparison is genuinely required, enable side-by-side comparison
(pricing tiers, specs). Otherwise prioritise: feature one option, provide search
and filtering up front, and default to a recommended choice. Too many options
degrades both the decision and how the whole experience is remembered.

**Chunking** — *A process by which individual pieces of an information set are broken down and then grouped together in a meaningful whole.*
Dictates: group content into visually distinct modules with a clear hierarchy.
Format data the way it is held in the head — phone numbers, card numbers, IBANs,
dates in their natural groups. Chunking is what makes a page scannable rather
than readable.

**Cognitive Bias** — *A systematic error of thinking or rationality in judgment that influence our perception of the world and our decision-making ability.*
Dictates: your own judgment about "obvious" design is itself biased. Confirmation
bias makes you read user research as agreement, so test with users who are not
you. Use anchoring, framing and defaults consciously and disclose them honestly —
the same mechanisms become dark patterns when they work against the user's goal.

**Cognitive Load** — *The amount of mental resources needed to understand and interact with an interface.*
Dictates: budget attention like bandwidth. *Intrinsic* load is the task itself —
reduce it with chunking and progressive disclosure. *Extraneous* load is
everything your design adds that does not serve understanding — decorative
motion, redundant chrome, inconsistent patterns, novel controls. Cut extraneous
load first; it is pure waste.

**Flow** — *The mental state in which a person performing some activity is fully immersed in a feeling of energized focus, full involvement, and enjoyment in the process of the activity.*
Dictates: match challenge to skill — too hard frustrates, too easy bores. Sustain
flow with immediate feedback on every action, responsive systems, and zero
unnecessary friction. Do not interrupt a user in flow with modals, tours or
upsells; defer them to a natural boundary.

**Mental Model** — *A compressed model based on what we think we know about a system and how it works.*
Dictates: match the design to the user's model of the domain, not the engineer's
model of the database. Folders, carts, drafts, trash and undo are mental models
worth borrowing. Closing the gap between your model and theirs is research work:
interviews, personas, journey maps, empathy maps — not intuition.

**Miller's Law** — *The average person can only keep 7 (plus or minus 2) items in their working memory.*
Dictates: chunk content so each group is graspable. Do NOT use "seven" to justify
arbitrary limits — the number is about chunks in memory, not items on a screen,
and a visible list is not held in memory at all. Capacity varies with prior
knowledge and context.

**Paradox of the Active User** — *Users never read manuals but start using the software immediately.*
Dictates: nobody reads the docs, the tour or the tooltip wall. Design the product
to be learnable by use: sensible defaults, reversible actions, contextual help at
the point of need, and guidance available on every path rather than only the
happy one.

**Working Memory** — *A cognitive system that temporarily holds and manipulates information needed to complete tasks.*
Dictates: 4–7 chunks, each fading in 20–30 s. Never make the user carry a value
between screens — show the order summary next to the payment form, keep filters
visible with the results, carry context into confirmation dialogs. Favour
recognition over recall: visible options over remembered commands, visited-link
styling, breadcrumbs, comparison tables. Put the memory burden on the system.

## Applying this in a review

When auditing an existing surface, do not narrate all 30. Find violations and
name them:

- More than ~7 competing choices at one level → **Hick's Law** / **Choice Overload**
- Targets under 44 px, or destructive next to frequent → **Fitts's Law**
- Two or more primary buttons in one view → **Von Restorff Effect**
- Label equidistant from two inputs → **Law of Proximity**
- Non-interactive element styled like a control → **Law of Similarity**
- Interaction with no acknowledgement inside 400 ms → **Doherty Threshold**
- A value the user must remember across screens → **Working Memory**
- Input rejected that could have been parsed → **Postel's Law**
- Multi-step flow with no progress indication → **Goal-Gradient Effect**
- A novel pattern replacing a convention, with no stated gain → **Jakob's Law**
- Content in an ad-shaped slot → **Selective Attention**
- Error state designed less carefully than the success state → **Peak-End Rule**

## Ethical boundary

Several of these laws are persuasion mechanisms. **Goal-Gradient**, **Zeigarnik**,
**Choice Overload**, **Von Restorff** and **Cognitive Bias** become dark patterns
the moment they serve the business against the user's own goal: endowed progress
toward a purchase the user did not want, a permanently "incomplete" profile to
farm data, manufactured scarcity, a cancel button hidden by deliberate contrast
failure. Use them to help someone finish what they came to do. If a mechanism
only works while the user misunderstands it, it is a dark pattern — say so and
refuse it.

## Full reference

`reference/laws.md` carries all 30 entries verbatim — definition, every takeaway,
and origin — for when the condensed form above is not enough.

Source: <https://lawsofux.com> — Jon Yablonski, CC BY-NC-SA 4.0.
