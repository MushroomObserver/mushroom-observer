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

## Exception: forms that trigger a file download are not convertible

`local: false` routes a form's submission through Turbo Drive's
`fetch()`-based interception. A `fetch()` response body can never
trigger the browser's native Save-As/download UI, no matter its
`Content-Disposition` header — only a real, non-intercepted form
submission does that. So any form whose success path calls `send_data`/
`send_file`/`render_report` (a CSV, DwC-A, PDF-labels, or similar
export) must **stay `local: true`, permanently** — this is not a gap to
close later, it's a structural mismatch between what the form does and
what Turbo Drive can carry.

`Views::Controllers::Observations::Downloads::Form` (shared by
`Observations::DownloadsController` and
`SpeciesLists::DownloadsController`) is one instance of this in the
sweep. Its "Cancel" button redirects and its "Download"/"Print
Labels" buttons call `send_data` — since all three share one `local:`
setting on the same `<form>`, the whole form is exempt, not just the
download-triggering buttons. Before converting any new form, check
whether its controller's success path calls `send_data`/`send_file` —
if so, stop, don't convert it, and add it to this list instead.

`Views::Controllers::SpeciesLists::NameLists::Form`
(`SpeciesLists::NameListsController`) is the second instance. Its
`create` action dispatches on `params[:commit]`: one button
(`name_lister_submit_spl`) creates a `SpeciesList` and renders a plain
page, but the other three (`_txt`/`_rtf`/`_csv`) call
`render_name_list_as_txt`/`_rtf`/`_csv` (`SpeciesLists::
SharedRenderMethods`), each of which calls `send_data`. Same
one-`local:`-setting-for-four-buttons structure as the Downloads form
— stays `local: true` permanently.

## HARD RULE: a same-URL `200` re-render on a Turbo-enabled form hangs the browser

**Never let a Drive-category response return a plain `200` at the same
URL it was submitted to — always either redirect, or return a non-2xx
status, even when nothing actually "failed."** This is not a style
preference; it's confirmed, reproducible browser breakage with **no
error, no exception, no console message** — the page just never
navigates and the flash never appears, indistinguishable from a hung
network request unless you go looking with a real browser.

Confirmed directly: `OccurrencesController`'s project-gaps
confirmation (`create_occurrence`'s `render_project_confirmation` and
`update`'s `redirect_after_update` re-render) both render the *same*
full-page URL at plain `200` after a POST/PATCH, on a form with
`local: false`. `occurrence_edit_form_system_test.rb`'s two submission
tests failed with "expected to find css `#flash_notices.alert-success`
but there were no matches" — even at an explicit 8-second wait, in a
real browser (Cuprite). Instrumenting `turbo:submit-end` showed
`success=undefined` and no navigation ever occurred. Forcing
`status: :unprocessable_content` on the exact same re-render fixed
both tests immediately, running in under 6s. The same fix was then
needed in two more places that had independently made the identical
"leave it at 200, nothing really failed" call before this was
understood: `Descriptions::Merges#warn_and_render_edit_description_form`
(the merge-conflict page) and `InfoController#textile_sandbox_create`
(a live-preview tool with no failure concept at all — 422 here is
purely a Turbo-mechanics necessity, not a claim that the preview
"failed").

**The takeaway supersedes earlier guidance in this doc**: the three
response-target categories above still correctly identify *whether*
Turbo cares about status at all (redirect / frame / stream → no), but
within the "full-page Drive re-render" category, the right status is
never "200 because this is a legitimate next step, not a failure" —
Turbo Drive doesn't know or care about REST semantics, only whether
the URL changed and whether the status is 2xx. Same URL + 2xx = Drive
tries to treat it as a successful new "visit" and — per this
investigation — that path is broken for a same-URL response. Same URL
+ non-2xx = Drive correctly redisplays in place. If a full-page
re-render doesn't redirect, it needs `:unprocessable_content`,
**full stop, regardless of whether anything semantically failed.**

This means: **every Drive-category full-page re-render found in this
sweep needs a non-2xx status, with no exceptions** — there is no
legitimate "leave it at 200" case for a same-URL POST/PATCH re-render
under Turbo. If you find yourself reasoning "this isn't really a
failure, so 200 is more correct" for a same-URL re-render, that
reasoning is exactly what produced this bug three separate times in
this sweep — stop and force the non-2xx status instead.

## CRUD buttons are a separate, already-solved mechanism — audit, don't convert

Besides the `New`/`Edit` form, a controller's pages (`index`, `show`,
and the form pages themselves) usually also render mutation buttons —
destroy, activate, merge, add/remove-curator, etc. — via
`Components::Button::CRUDBase` (dispatched through `Button(type: :post/
:put/:patch/:delete, ...)`). **These already opt into Turbo
unconditionally** — `button_html_options` in
`app/components/button/crud_base.rb` hardcodes
`form_data = { turbo: true }` on every instance, restored after a prior
regression (see git log: "Restore Turbo on CRUD buttons"). There are no
raw `button_to(` calls left anywhere in `app/views/controllers/` or
`app/components/` outside `CRUDBase` itself — every CRUD button in the
app already submits via Turbo. **Nothing to flip on the button side.**

What still needs auditing, per controller, as part of each batch: the
**target actions** those buttons hit. A button being Turbo-enabled
doesn't help if its target action does a full-page re-render without
the right status — same failure mode as an unconverted form, just
reached via a button instead. Concretely, for each controller in a
batch:

1. Grep that controller's own view tree (`index.rb`, `show.rb`, and
   anything nested under them — not just `new.rb`/`edit.rb`) for
   `type: :post`/`:put`/`:patch`/`:delete`.
2. For each hit, resolve `target:` to the actual controller#action
   (follow named routes/resources in `config/routes.rb` — a button
   rendered on one controller's page often targets a *different*
   controller, e.g. a curator-removal button on `HerbariaController`'s
   show page actually targets `Herbaria::CuratorsController#destroy`).
3. Read that action. If it always redirects (the overwhelmingly common
   shape for destroy/toggle/merge actions), or responds via
   `format.turbo_stream`/a `turbo_frame_tag`-wrapped response, it's
   already safe — no change needed. Only a genuine full-page re-render
   on failure (rare for these action shapes) needs the same
   `_invalid`/`422` treatment described above.

This is a one-hop trace (batch's pages → button → target action), not
unbounded recursion — a button that merely *links* to another page
(not a CRUD button, just an `a href`) that itself has further buttons
is that other page's own controller's concern when its turn in the
sweep comes up, not this batch's.

Worked example from batch 1: `HerbariaController`'s show page renders
a curator-removal button (`herbaria/show/curator_table.rb`) targeting
`Herbaria::CuratorsController#destroy` — a controller not otherwise in
this sweep's Form-based inventory at all. Traced it, found it always
redirects, no change needed — but the point is it had to be traced,
not assumed safe because "it's just a destroy button."

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

There is **no exception** to category 3 for "this isn't really a
failure" cases — see the hard rule above. An earlier version of this
doc carved out `InfoController#textile_sandbox_create` (a pure
preview/sandbox tool) as a legitimate case for keeping `200`; that was
wrong and has been fixed. Same-URL re-renders always need the non-2xx
status, regardless of whether the action semantically "failed."

## Testing: controller tests are enough *once you follow the hard rule above*

The mechanical part of this conversion (`local: false` → `data-turbo`
attribute, failure path → `422`) is fully verifiable through the
existing Rails request/response cycle — status codes and rendered HTML
are exactly what a controller test already inspects, and MO's flash
mechanism doesn't need a browser either (see "Flash" below). This
holds *as long as every full-page Drive re-render gets a non-2xx
status per the hard rule above* — controller tests can't tell the
difference between "200, and Turbo handles it fine" and "200, and
Turbo silently hangs," because they never execute Turbo's own JS.
That gap is exactly how the same-URL-200 bug survived three separate
sweep decisions undetected. The fix isn't "add a system test for every
form" — it's "never emit the shape that only a system test can catch
in the first place." Once every Drive re-render is redirect-or-non-2xx,
controller tests are sufficient again.

When you genuinely can't avoid ambiguity (a new response shape this
doc doesn't already cover, or you're not sure whether a case falls
into the same-URL-200 trap), run the controller's existing system test
if one exists — see "Why not system tests" below for how cheap that
check actually is.

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

## Why not system tests (mostly) — and when to actually run one

A parallel PR (#5055, Observations Turbo conversion) built genuine
Capybara/Cuprite system-test infrastructure — `wait:` params on
`assert_flash*` in `test/capybara_session_extensions.rb` — after
discovering Turbo's async page-body swap is measurably slower than a
normal full-page render, which made naive system-test flash assertions
flaky. That infrastructure is for verifying **actual browser/JS
behavior** and is worth its cost for a page with non-trivial
client-side interaction.

For most of this sweep, a system test per converted form still isn't
worth it — the conversion is mechanical, and correctness is provable
at the HTTP layer *once the hard rule above is followed*. But that
qualifier matters: the same-URL-200 bug is real, it was silent, and it
survived three independent, individually-reasoned "this one's fine at
200" decisions across this sweep before a system test caught it. So
the practical policy is:

- **Writing a new full-page Drive re-render?** Apply the hard rule
  (redirect or non-2xx, always) and controller tests are sufficient —
  no need to add a system test just because the sweep touched the
  controller.
- **Does the controller already have a system test that exercises a
  form submission this sweep touched?** Run it before calling the
  controller done. It's cheap (one `bin/rails test` invocation) and
  it's the only thing that would have caught this bug on the first,
  second, or third occurrence. `OccurrencesController`,
  `Names::Descriptions::MergesController`/
  `Locations::Descriptions::MergesController`, and `InfoController`
  all had this exact bug ship past controller-test review; only
  `occurrence_edit_form_system_test.rb` (which happened to already
  exist) caught it.
- **Genuinely unsure whether a same-URL response is redirect, 2xx, or
  the Drive case at all?** That uncertainty is itself the signal to
  check for an existing system test rather than guess from the
  controller code alone.

Writing a *new* system test purely for sweep coverage is still
overkill — the fix is a one-line status code, not a new test file. But
"don't add tests" and "don't run the tests that already exist" are
different things; do the latter whenever one is available.
