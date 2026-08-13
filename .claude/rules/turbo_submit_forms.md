# Converting a Phlex form to Turbo submission

Tracked by issue #5052. `Turbo.config.forms.mode = "optin"` — a form only
submits via Turbo if it (or an ancestor) carries `data-turbo="true"`.
`Components::ApplicationForm` defaults to `local: true` (no Turbo); pass
`local: false` to opt a form in.

## Turbo Drive vs. Turbo Frames vs. Turbo Streams — three different mechanisms

This sweep is specifically a **Turbo Drive** conversion. Don't conflate
it with Turbo Frames or Turbo Streams — they're separate Turbo features
with different response contracts, and mixing up which one a given
controller uses is how you end up applying the wrong fix (see the
`Admin::BlockedIpsController` revert below).

- **Turbo Drive** — what `local: false` opts a form into. The response
  is ordinary HTML (`text/html`), and **the HTTP status code is the
  success/failure signal**: a 2xx/3xx response is a "visit" (Drive
  pushes a new history entry, treats it as a fresh page); a 4xx/5xx
  response (our `:unprocessable_content`) is rendered in place as an
  error redisplay, with no history push. This is exactly why every
  full-page re-render failure path in this sweep needs
  `render_new_view_invalid`/`render_edit_view_invalid` — a validation
  failure that still returned `200` would make Drive treat the
  redisplayed form as if the submission had succeeded.
- **Turbo Frames** — a `<turbo-frame id="...">` scopes the swap to just
  that subtree. A response gets matched into the frame by finding a
  same-`id` `<turbo-frame>` in the body — **status code is irrelevant**;
  Frames don't distinguish 200 from 422, they just look for the
  matching id. Confirmed the hard way: forcing `:unprocessable_content`
  onto `Admin::BlockedIpsController`'s frame-wrapped `Manager` form
  broke the pre-existing `test_turbo_frame_responses` test, which
  correctly expected `:success` — reverted.
- **Turbo Streams** — an explicit, separately-negotiated response format
  (`format.turbo_stream` / `Accept: text/vnd.turbo-stream.html`),
  independent of whatever `local:` the form itself has. The body is one
  or more `<turbo-stream action="..." target="...">` elements that
  surgically patch specific DOM nodes (append/prepend/replace/update/
  remove) — there's no whole-page navigation concept here at all, so
  **status code again isn't the failure signal**. MO's own convention
  (`HerbariaController`, `CommentsController`) keeps these responses at
  a plain `200` even on validation failure — the "this failed" signal
  is carried by *which* stream got rendered (a `replace`-the-form
  stream vs. a modal-closing `remove` stream) and by the flash content
  inside it, not by HTTP status. Don't try to make a turbo_stream
  failure path return `422` — there's nothing on the Stream side that
  interprets it, and MO's existing controllers don't do this.

Practical upshot: before touching a failure path's status code, check
which of these three the response actually is. Only the Drive case
(full-page re-render, no `turbo_frame_tag`, no `format.turbo_stream`
branch) needs the `422` treatment described below.

## The conversion, per controller

1. **`local: false`** on every `Form.new(...)` call in the controller's
   `New`/`Edit` action views (`app/views/controllers/<c>/new.rb`,
   `edit.rb`).
2. **`render_new_view`/`render_edit_view`** — the controller's GET
   `new`/`edit` actions (and any success-path re-render) call these.
   Give them `status: :ok, **render_opts` and forward into
   `render(View.new(...), status: status, **render_opts)`. Rename any
   differently-named existing method (`render_new_phlex`,
   `render_edit`, `render_phlex_new`, …) to this pair for consistency
   across the sweep.
3. **Route every failure-path re-render through
   `render_new_view_invalid`/`render_edit_view_invalid`**
   (`ApplicationController#render_new_view_invalid`/
   `#render_edit_view_invalid`, added in #5054) instead of calling
   `render_new_view`/`render_edit_view` (or a bare `render(...)`)
   directly. These are generic dispatchers: call the including
   controller's own `render_new_view`/`render_edit_view` with no forced
   kwargs, then set `self.status = :unprocessable_content` afterward —
   works regardless of the subclass method's own signature, so no
   per-controller override is needed for this pair.
4. **A controller with two distinct forms** (e.g. login +
   password-reset) can't route both through the canonical
   `render_new_view_invalid` name. Give the second form its own local
   `_invalid` wrapper mirroring the same two-line pattern:
   ```ruby
   def render_email_new_password_view_invalid(**)
     render_email_new_password_view(**)
     self.status = :unprocessable_content
   end
   ```

## Does this controller need a status-code change at all?

Three response-target categories, decided per failure path — get this
wrong before writing any test and you'll chase a false failure:

1. **Redirect-on-failure** — the failure path calls `redirect_to`, not a
   re-render. Turbo already handles redirects natively. **No status
   change needed at all** — `local: false` on the Form is the only
   change (`CollectionNumbersController`, `HerbariumRecordsController`).
2. **Turbo Frame / Turbo Stream scoped** — a form wrapped in
   `turbo_frame_tag(...)`, or a `format.turbo_stream` branch. Turbo
   Frames match by `<turbo-frame id="...">` in the body regardless of
   status; Streams target by DOM id. **No status change needed** —
   forcing `:unprocessable_content` here actively breaks an existing
   frame-response test (confirmed on `Admin::BlockedIpsController`;
   reverted after `test_turbo_frame_responses` failed).
3. **Full-page Drive re-render** — the failure path always re-renders
   the same full page (no turbo-frame wrapper, no turbo-stream branch).
   **Needs `:unprocessable_content`** via `render_new_view_invalid`/
   `render_edit_view_invalid`, so Turbo Drive swaps the body in place
   instead of treating the response as a normal navigation
   (`Images::LicensesController`).

Exception worth a deliberate call-out, not a silent skip: a full-page
always-re-render controller whose action is a pure preview/sandbox with
no real validation-failure concept (`InfoController#textile_sandbox_create`)
may legitimately keep `200` — check for an existing test asserting the
current status before changing it, and leave it alone with a note if
changing it would contradict that test and the semantics.

## Testing: controller tests are enough — no system tests needed for this sweep

The mechanical part of this conversion (`local: false` → `data-turbo`
attribute, failure path → `422`) is fully verifiable through the
existing Rails request/response cycle. Controller tests already render
real HTML into `@response.body` and already exercise the full
`session[:notice]` flash mechanism (see "Flash" below) — a browser and
JS engine add nothing beyond what `assert_select` on that body already
proves for this specific class of change. Reach for a system test only
when the change involves actual client-side behavior beyond opt-in
markup (a Stimulus controller reacting to the Turbo swap, a JS-driven
multi-step flow) — not for the routine conversion pattern itself.

Two assertions close the practical gap, both addable to a controller
test that already exists (no new test files):

1. **The failure path returns 422**, for the full-page-re-render
   category above:
   ```ruby
   assert_unprocessable
   ```
   (No test change needed at all for the redirect-on-failure or
   turbo-frame/turbo-stream categories — their existing
   `assert_redirected_to`/`assert_response(:success)` already covers
   the unchanged behavior.)

2. **The re-rendered form still carries `data-turbo="true"`** — this is
   the part a status-code assertion alone doesn't prove. The generic
   mechanism (`local: false` → `data-turbo="true"`) is already
   unit-tested once, in the abstract, at
   `test/components/application_form_test.rb`. That does **not** prove
   any individual controller's view actually passes `local: false` —
   only a request through that specific controller does. Add one
   `assert_select` at (or near) the controller's invalid-pathway
   assertion — not at every failure-case call site in a test method
   that repeats the same form several times, and not a new test file:
   ```ruby
   post(:create, params: { new_user: params.except(:password) })
   assert_flash_error
   assert_unprocessable
   assert_select("form[data-turbo='true']")
   ```
   This is the assertion that actually matters for Turbo: it proves the
   422 response Turbo Drive just swapped in is itself still
   turbo-enabled, so a corrected resubmit continues through Turbo
   rather than silently falling back to a full navigation.

## Testing a turbo_stream branch directly

A controller test can request the `format.turbo_stream` branch directly
— no system test, no Capybara — by passing `format: :turbo_stream` to
the action call. The response body is real markup
(`<turbo-stream action="...">` wrapping ordinary HTML), so
`assert_select` reads it exactly like any other rendered response.
Worked example, `Observations::NamingsControllerTest#test_edit_form_turbo`:

```ruby
def test_edit_form_turbo
  params = edit_form_test_setup
  nam = namings(:coprinus_comatus_naming)
  get(:edit, params:, format: :turbo_stream)
  assert_select("#modal_obs_#{nam.observation_id}_naming_#{nam.id}")
  assert_no_flash(
    on_fail: "User should be able to edit his own Naming without " \
             "warning or error"
  )
end
```

`CommentsController` has the equivalent for a flash-carrying
turbo_stream response — assert the specific stream target, not just
that a `<turbo-stream>` tag exists somewhere:

```ruby
get(:new, params:, format: :turbo_stream)
assert_select("turbo-stream[action='update'][target$='_flash']")
assert_flash_error
```

So "no status-code change needed" for the turbo-frame/turbo-stream
category (above) doesn't mean "no test needed" — it means the
verification is a direct `format: :turbo_stream` request against that
branch instead of a status assertion. Use this whenever a converted
controller has its own `format.turbo_stream` branch and no existing
test exercises it directly.

This is an already-widespread, pre-existing convention in MO's test
suite, not a technique invented for this sweep — `grep -rn "format:
:turbo_stream" test/controllers/` turns up examples across many
controllers (`comments_controller_test.rb`, `herbaria_controller_test.rb`,
`observations/namings_controller_test.rb`, `export_controller_test.rb`,
`sequences_controller_test.rb`, `translations_controller_test.rb`,
`inat_imports_controller_test.rb`, and more). Check the target
controller's existing test file for one before writing a new pattern
from scratch — there's a good chance the shape you need is already
there to copy.

## Flash

**MO does not use Rails' `flash`/`flash.now` mechanism** — see the
block comment at the top of
`app/controllers/application_controller/flash_notices.rb`. It uses its
own `session[:notice]`, cleared by the layout on every render (not on
redirect). This means the classic Rails "used `flash[:x]` before a
`render`, message shows twice" bug class doesn't apply here — MO's
`flash_clear` already discriminates render-now vs. carry-to-next-request
correctly, and `assert_flash_error`/`assert_flash_success`/
`assert_flash_warning` (`test/flash_extensions.rb`, available in both
functional and integration tests) verify exactly that: they check
`@controller.instance_variable_get(:@last_notice) || session[:notice]`,
which reflects the render-vs-redirect distinction MO's own mechanism
makes. No additional flash test infrastructure is needed for this
sweep — the existing `assert_flash_error`/`assert_unprocessable` pair on
a failure path is a complete, meaningful check for MO's flash contract,
without needing to parse the rendered flash HTML.

## Why not system tests

A parallel PR (#5055, Observations Turbo conversion) built genuine
Capybara/Cuprite system-test infrastructure — `wait:` params on
`assert_flash*` in `test/capybara_session_extensions.rb` — after
discovering Turbo's async page-body swap is measurably slower than a
normal full-page render, which made naive system-test flash assertions
flaky. That infrastructure is for verifying **actual browser/JS
behavior** (does Turbo really intercept the submit, does the swap
settle before the assertion runs) and is worth its cost for a page with
non-trivial client-side interaction. It is not needed for this sweep:
the conversion here is a mechanical, declarative opt-in
(`local: false` + a status code), fully provable at the HTTP layer, and
adding a system test per converted form would multiply suite runtime
for no additional signal. If a future controller in this sweep turns
out to have real client-side logic riding on the Turbo swap, that's the
signal to add a targeted system test for that one controller — not a
blanket policy change.
