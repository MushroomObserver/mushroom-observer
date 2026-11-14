# System tests: poll Stimulus controller state, not just the DOM

Capybara's built-in waiting (`click`, `fill_in`, `assert_selector(wait:)`)
polls for a CSS selector to appear or match. That's the right default —
use it everywhere it fits. It breaks down for one specific class of
async UI: **Stimulus controller state with no reliable DOM proxy.**

## When a DOM-selector wait isn't enough

- **Debounced/polled JS has no DOM event to hook.** A `setTimeout`-based
  debounce (e.g. `GeocodeController#sendPointChanged`, which waits 1s
  and re-arms on every `input` event) has no "debounce settled" DOM
  mutation to wait on. The target attribute just eventually changes —
  polling the controller object directly is the only way to ask "has
  this actually resolved" instead of "does this element currently,
  possibly transiently, have this attribute."
- **A DOM attribute can flip through an intermediate state.** A
  `data-type` swap can briefly land on the right value from a stale or
  partial update before the underlying data the test actually cares
  about (e.g. `controller.request_params`) has caught up. A selector
  match doesn't prove the state behind it is settled.
- **Better failure diagnosis.** A `Timeout::Error` from a helper that
  names exactly what it was polling for ("waiting for map outlet
  ready") is more useful than "expected to find css X but there were
  no matches" — the latter doesn't distinguish "never fired" from
  "fired with the wrong value" from "fired and got overwritten."

## HARD RULE: never put `:not()` in a Capybara selector string

Not "avoid it in count waits" — avoid it everywhere, including a plain
single-element `assert_selector`/`find`. `:not()` inside a Capybara
selector (`.foo:not(.bar)`, `input:not([disabled])`) has been found
unreliable under this suite's Cuprite setup, confirmed on both class
and attribute negation, both single-element and multi-element waits.
`ObservationFormSystemTest#test_edit_observation_extracts_exif_from_saved_images`
found 0 matches at `wait: 20` for `.upload-status-check:not(.d-none)`,
every run, even standalone with zero contention — not a timing issue:
a direct `evaluate_script('document.querySelectorAll(...).length')`
poll for the identical condition passed immediately, same run, same
page. Widening the wait repeatedly didn't help, because the assertion
mechanism itself couldn't converge, not because it was slow. A sweep
of `test/system/` found the same pattern (`:not(.class)`,
`:not([disabled])`) in two other files that hadn't failed yet —
fixed those too, on the assumption that "hasn't failed yet" means
"hasn't been hit under load yet," not "is fine."

**Fix:** replace `assert_selector("X:not(Y)")` with
`assert_selector("X")` (if existence also needs asserting) plus
`assert_no_selector("XY")` — i.e. assert the *positive* form doesn't
exist, rather than asserting the negative form does. For a
multi-element count wait, poll a positive count directly instead:
`total - document.querySelectorAll("X.Y").length >= count` rather
than `document.querySelectorAll("X:not(.Y)").length >= count`.

There's no known case where `:not()` is safe to reach for in this
suite — treat any new one as a bug on sight, not something to
evaluate case by case.

## The pattern

`test/system/observation_form_system_test.rb` has the working examples
— private helper methods, each polling one piece of Stimulus state via
`evaluate_script` + `window.Stimulus.getControllerForElementAndIdentifier`,
inside a `Timeout.timeout(10) { loop { ...; break if ready; sleep(0.1) } }`
wrapper instead of a fixed `wait:` on a selector assertion:

- `wait_for_map_outlet_ready` — polls `c.hasAutocompleterLocationOutlet`
- `wait_for_map_geocoder_ready` — polls `c.geocoder` (Google Maps loader
  promise resolved)
- `wait_for_autocompleter_match` — polls `(c.matches || []).length.positive?`
- `wait_for_autocompleter_request_params(lat:, lng:)` — polls
  `c.request_params` for the exact values a debounced swap should
  settle on, instead of trusting `assert_selector("[data-type=...]")`
  to mean the swap is finished (added fixing the flaky
  `test_zero_latitude_triggers_locality_lookup`, issue #5238's PR)

When a new test needs to wait on a similar async Stimulus dependency,
add a same-shaped private helper rather than reaching for a longer
`wait:` timeout or a `sleep`.

## Synthetic DOM events, not `fill_in`

A few of these tests also construct events directly —
`element.value = "..."; element.dispatchEvent(new Event("input", { bubbles: true }))`
via `execute_script` — instead of Capybara's `fill_in`. `fill_in`
simulates real keystrokes one at a time; a test that needs a specific
interleaving (e.g. setting both a lat and a lng field before either
one's `input` event fires) can't get that from keystroke-by-keystroke
simulation and has to build the event sequence by hand.

## Still the exception, not the default

Most system-test waiting should stay on Capybara's own mechanisms —
this pattern is for the narrow case where the precondition lives in
JS controller state with no clean DOM signal to wait on. Reach for it
only when a `wait:` bump or an existing helper doesn't hold up.
