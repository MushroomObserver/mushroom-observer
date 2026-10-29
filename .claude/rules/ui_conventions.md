# New UI — assume you can't see it, because you can't

Two halves of the same problem: spacing you cannot see, and
interaction affordances whose established form you will not find by
searching for the words in the request. Both are settled by looking
at a page that already does the thing.

## Visual spacing

### The failure mode

Claude sessions build and verify UI through tests, RuboCop, and HTTP
responses — none of which render pixels. A button jammed flush against
the image above it produces exactly the same green test suite as one
with comfortable margins, so nothing in the session's feedback loop
ever flags it. And the testing conventions (correctly) forbid pinning
cosmetic spacing classes in tests, so there is no regression signal
for polish either. The result, observed repeatedly across sessions and
developers: structurally correct pages whose interactive elements
touch their neighbors.

Concrete example (PR #5044): the observation scan page rendered each
photo's "Read Field Slip" button flush against the photo's bottom
edge. Correct DOM, passing tests, visibly cramped.

### The rule

When composing a new page or section, don't write bare structure and
stop when tests pass:

1. **Copy the spacing idiom from an existing page with the same
   shape.** Before writing a photo-grid, a button row, a label+control
   stack, find one already in `app/views/controllers/` or
   `app/components/` and match its margin/padding utility classes —
   don't reason spacing out from scratch.
2. **Any interactive control adjacent to an image or other media gets
   an explicit margin** (`mt-2` on the row below a photo, `ml-2`/
   `mr-2` beside one). Media elements have hard visual edges; text has
   built-in line spacing, images have none.
3. **Blocks stacked inside a panel or cell need vertical separation**
   — a bare `div { ... }` directly under another rendered element is
   the tell. If two siblings would touch, the second one needs a
   `mt-*`.

### What this doesn't replace

A human looking at the rendered page. Spacing utilities applied by
convention get new UI to "reasonable by default," not "reviewed."
Flag visually novel layouts for a human glance in the PR's test plan.

## Affordances — copy the page that already does it

### The failure mode

A request names an interaction in plain words — "a (?) with hover text",
"a red X that clears the field" — and `app/components/` holds a component
whose name matches those words. `Help(type: :tooltip)` is a tooltip.
`Icon(type: :x)` is an X. Both render. Neither is what MO uses for those
two jobs, and no test, RuboCop run or HTML assertion says so, because the
wrong affordance is structurally fine. What it breaks is consistency with
every other page, which only a person looking at the site notices.
Observed on PR #5426, twice in one form.

**A component matching the words in the request is not evidence that it is
the convention.** Find the page that already does the job and copy its
call.

### The conventions, as they stand

| Job | The call | A page that does it |
| --- | --- | --- |
| Longer explanation of a form field | `help: :tag.t, help_collapse: true` on the field helper — a question-mark trigger by the label, opening a collapsible well | `observations/form/details.rb` (`is_collection_location`) |
| Short explanation, always visible | `help: :tag.t` on the field helper | `locations/form.rb` |
| Destroy a record | `Button(type: :delete, target:, variant: :strip)` — the circled red X | `projects/aliases/table.rb` |
| Clear a value without a request | a plain `Button(variant: :strip, icon: :delete, class: "text-danger")` carrying a Stimulus action — same icon, no `button_to`, since a nested `<form>` inside a form breaks submission | `projects/external_sites/form.rb` |

`Help(type: :tooltip, ...)` is for a label that is not a form field at all
(the header marker for an applied content filter). It is not the
form-field help convention, and reaching for it there is the mistake
above.

When a job is not in this table, find a page doing something of the same
shape before writing markup, and add the row here afterwards.

## Read the markup you produced

Selector assertions pass against markup that is wrong in ways they do not
name — a doubled separator, a control with no gap beside it, a trigger
rendered in the wrong row. Before calling a new page done, render it and
read the HTML: a throwaway controller test writing
`Nokogiri::HTML(response.body).at_css("#the_panel").to_html` to a
scratchpad file costs a minute, and it is the nearest thing to seeing the
page. Delete it once read. On PR #5426 it caught a doubled colon space
and a missing margin that seven passing assertions had not.
