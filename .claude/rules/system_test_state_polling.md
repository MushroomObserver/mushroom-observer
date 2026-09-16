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
