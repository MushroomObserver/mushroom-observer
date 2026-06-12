# Bootstrap 3 checkbox/radio centralization TODO

## Why

When MO migrates to Bootstrap 4/5, the markup for checkboxes/radios
changes from BS3's `<div class="checkbox"><label><input>text</label></div>`
to BS4/5's `<div class="form-check"><input class="form-check-input">
<label class="form-check-label">text</label></div>`. If every
checkbox/radio rendering already flows through a small number of
centralized components/helpers, the migration is "change two files."
If the markup is scattered across dozens of call sites, the migration
is a grep-and-pray.

This TODO captures the audit done while landing PR #4250
([#4225 group C](https://github.com/MushroomObserver/mushroom-observer/issues/4225))
and a proposed order of work to get there.

## Two centralized paths already exist

- **Phlex world**: `Components::ApplicationForm::CheckboxField` and
  `Components::ApplicationForm::RadioField`. Both wrap each input in
  the Bootstrap 3 `.checkbox` / `.radio` div. Use the `checkbox_field`
  / `radio_field` helpers on `ApplicationForm` to render them
  (one-line call sites). Outside an `ApplicationForm` subclass, render
  the component directly against a `FieldProxy`.
- **ERB world**: `app/helpers/forms_helper.rb` exposes
  `check_box_with_label` / `radio_with_label`. Both wrap each input in
  the `.checkbox` / `.radio` div via `tag.div(class: wrap_class)`.

The four bare `f.check_box` / `f.radio_button` calls in
`forms_helper.rb` itself (lines 96, 115, 130, 149) are *inside* those
two wrappers — they're the centralization, not call sites to migrate.

## Sites bypassing the centralization (as of 2026-05-13)

### Phlex components — bare `input(type: …)`

- `app/components/form_carousel_item.rb:155` — radio for
  `thumb_image_id`.
- `app/components/activity_log_type_filters.rb:65` — checkbox for
  `q[type][]`.
- `app/components/project_violations_form.rb:271, :275` — two radios
  for `location_id`.

### ERB partials — bare `check_box_tag` / `radio_button_tag` /
`f.check_box` / `f.radio_button`

Matrix-card forms (visually similar to the occurrence forms):

- `app/views/controllers/field_slips/_recent_observations.erb:12, :21`
- `app/views/controllers/field_slips/_edit_observations.erb:28, :37,
  :59, :68`

Other:

- `app/views/controllers/shared/_images_to_remove.erb:21` — checkbox
  inside an `f_s.check_box(image.id, …)` call.

### Helpers — bare `check_box_tag` / `f.check_box`

- `app/helpers/api_keys_helper.rb:67` — `check_box_tag(:verified, …)`.
- `app/helpers/namings_helper.rb:408` — `f_r.check_box(:check, …)`.

## Proposed order of work

Doing the conversions in this order leverages each step to make the
next easier.

### 1. Convert the field-slip matrix forms to Phlex

`field_slips/_recent_observations.erb` and
`field_slips/_edit_observations.erb` are matrix-style observation
selection forms — same shape as the `OccurrenceForm` /
`OccurrenceEditForm` we just landed in PR #4250. The occurrence forms
establish the canonical Phlex pattern for matrix-cell checkboxes and
radios (`field(:foo).checkbox` / `.radio` per row, `wrap_class: "my-0"`
to drop the Bootstrap block margin inside the card). Apply the same
pattern here. Likely involves creating
`Components::FieldSlipRecentObservationsForm` and
`Components::FieldSlipEditObservationsForm` (or a shared component).

### 2. Convert `shared/_images_to_remove` to Phlex

Smaller partial, but it lives next to image-form components that are
already Phlex (e.g. `FormImageFields`, `FormCarouselItem`). Converting
this gets the whole "image removal" workflow under one Phlex
component. Use `CheckboxField` for the per-image checkbox.

### 3. Convert the remaining ERB callers to Phlex (or use
`check_box_with_label`)

The remaining ERB site (none after steps 1–2 land — `_images_to_remove`
is the last ERB matrix). If new bare ERB call sites appear, route them
through `check_box_with_label` / `radio_with_label` as a stopgap
before a Phlex conversion.

### 4. Convert the two helpers

- `api_keys_helper.rb:67` — likely the API keys index page; convert
  the page (or just that helper call) to Phlex and use `CheckboxField`.
- `namings_helper.rb:408` — similar; convert the relevant page or
  partial.

### 5. Convert the remaining Phlex components

- `form_carousel_item.rb` — the `thumb_image_id` radio. The carousel
  is already Phlex; this is a one-line swap to `radio_field` /
  `RadioField` once the surrounding form context is sorted out.
- `activity_log_type_filters.rb` — checkbox for `q[type][]`. Likely
  outside a Superform form (it's a filter UI). Use `CheckboxField`
  with `FieldProxy`.
- `project_violations_form.rb` — two radios for `location_id`. Already
  inside an `ApplicationForm` (judging by the file name). Use
  `radio_field`.

### 6. (Eventual) Bootstrap 4/5 migration

After steps 1–5, every checkbox/radio in MO flows through either
`CheckboxField` / `RadioField` (Phlex) or `check_box_with_label` /
`radio_with_label` (ERB stragglers, if any remain). The BS4/5
migration changes the HTML in those four files; every call site
updates automatically.

## Verification

After each step:

- `bundle exec rubocop` clean on changed files.
- Component tests pass.
- Self-review grep on the relevant directories:
  - Phlex: `grep -rEn '\binput\([^)]*type:.*(\bcheckbox\b|\bradio\b)' app/components/`
    should return nothing outside `application_form/{checkbox,radio}_field.rb`.
  - ERB: `grep -rEn '\bcheck_box_tag\b|\bradio_button_tag\b|\.check_box\b|\.radio_button\b' app/views/ app/helpers/`
    should return only the four wrapped calls inside `forms_helper.rb`.

## Out of scope

- Restyling the checkbox/radio inputs themselves (Bootstrap 3 doesn't;
  MO doesn't). If we want branded checkboxes/radios that look like
  buttons or modern toggle controls, that's a separate ticket.
- Native vs 3-select date input (`Components::ApplicationForm::DateField`
  is 3-select; PR #4250 documents the option of a `NativeDateField`).
