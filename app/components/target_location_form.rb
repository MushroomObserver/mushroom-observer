# frozen_string_literal: true

# Modal-resident form for adding a comma-suffix of an observation's
# location name as a new target location for a project. Extracted from
# Components::ProjectViolationsForm so its modal markup can be tested
# in isolation and so the hand-rolled CSRF / `_method` inputs can be
# replaced by Superform's automatic ones (per the
# `phlex_conversions.md` ban on hand-rolled form-control HTML).
#
# The form posts `do=add_target_location`, `obs_id=<id>`, and
# `location_id=<id>` (the radio selection — the comma-suffix the user
# picked) to `project_violations_update_path` with PUT. The route only
# accepts PUT, not PATCH, so we override Superform's default `_method`
# value via `method: :put` in the initializer.
#
# Two render modes inside `.modal-body`:
#
#   - **No suffixes available** (e.g. blank `obs.where`) — renders only
#     the "no suffixes" message. `.modal-footer` shows just Cancel.
#   - **Suffixes available** — renders the help paragraph + a RadioField
#     where each existing suffix is a submittable choice and each
#     missing suffix is a disabled row with a "Create" link sibling
#     (links open `/locations/new?display_name=...` in a new tab).
#     `.modal-footer` shows Submit + Cancel.
#
# Uses Modal's `:form_content` slot (added in #4293) so the form spans
# both `.modal-body` and `.modal-footer` — submit is naturally inside
# the form. ProjectViolationsForm renders one Modal per violating obs
# and points each to a TargetLocationForm via `with_form_content`.
class Components::TargetLocationForm < Components::ApplicationForm
  # Declares to Modal callers (and any wrapper that auto-detects) that
  # this form renders its own `.modal-body` and `.modal-footer` divs.
  def self.owns_modal_sections?
    true
  end

  # Public class helper so callers can decide whether to render this
  # form at all — if there are no usable suffixes the form would have
  # no submittable choices, and the caller should render a static
  # "no suffixes" message in `.modal-body` + a Cancel in `.modal-footer`
  # instead.
  def self.applicable?(obs)
    suffixes_for(obs).any?
  end

  # Suffixes of obs's location/where, excluding any bare-country
  # suffix (Q3 of #4136). Public class method so callers can call
  # `applicable?` without instantiating the form.
  def self.suffixes_for(obs)
    name = obs.location_id ? obs.location&.name : obs.where
    return [] if name.blank?

    comma_suffixes(name).
      reject { |s| Location.understood_countries.include?(s) }
  end

  # Progressively-shorter trailing slices of a comma-separated name,
  # including the full name itself. So "Berkeley, Alameda Co.,
  # California, USA" yields four candidates; the bare-country
  # entries are filtered out by `suffixes_for`. JoeCohen review on
  # PR #4182: the full obs location name is itself a valid target
  # candidate (e.g. for state- or national-park-level locations like
  # "California, USA"), so the previous "(1..)" range that omitted
  # the full name was wrong.
  def self.comma_suffixes(name)
    parts = name.split(",").map(&:strip).reject(&:empty?)
    return [] if parts.empty?

    (0..(parts.length - 1)).map { |i| parts[i..].join(", ") }
  end

  def initialize(obs:, project:, **)
    @obs = obs
    @project = project
    # method: :put — the route is PUT-only (Superform would default to
    # PATCH for a persisted model and the request would route-mismatch).
    # The project is the thing being mutated (a target_location entry
    # is added to its target_locations list), so it's the natural
    # Superform "model" for dom.id. No fields bind to it — every
    # input is named explicitly.
    super(project, method: :put, **)
  end

  def form_action
    project_violations_update_path(project_id: @project.id)
  end

  # Callers (ProjectViolationsForm) check `applicable?(obs)` first and
  # render a static body+footer when there are no suffixes — so by the
  # time this form is rendered, `suffixes` is guaranteed non-empty.
  # Symbol-keyed hidden_field goes through Superform's Field, which
  # auto-namespaces the input as `name="project[do]"` etc. (the model
  # is the Project). Project doesn't define these as attributes, so
  # `@object.public_send(:do)` would noop; the explicit `value:` here
  # wins. The controller reads them via `params.dig(:project, :do)`.
  def view_template
    super do
      hidden_field(:do, value: "add_target_location")
      hidden_field(:obs_id, value: @obs.id)
      div(class: "modal-body") { render_suffix_radios }
      div(class: "modal-footer") { render_footer_buttons }
    end
  end

  private

  def render_footer_buttons
    submit(:form_violations_modal_target_location_submit.l,
           as: :button, btn_class: "btn-primary")
    whitespace
    button(type: "button", class: "btn btn-default",
           data: { dismiss: "modal" }) { :CANCEL.l }
  end

  def render_suffix_radios
    p { :form_violations_modal_target_location_help.l }
    # Use a FieldProxy with the Superform-namespaced name
    # (`project[location_id]`, derived from `field(:location_id).dom.name`)
    # so the radio's `name` attr matches the rest of the form's
    # namespacing. We can't go through Superform's `field(:x).radio(...)`
    # directly because Project doesn't define a `location_id` attribute
    # and Superform's option_checked? reads from the model — pre-selection
    # would never fire. The FieldProxy keeps explicit value control.
    proxy = Components::ApplicationForm::FieldProxy.new(
      nil, field(:location_id).dom.name,
      first_existing && existing[first_existing]&.id
    )
    render(Components::ApplicationForm::RadioField.new(
             proxy, *suffix_choices
           ))
  end

  # Each suffix becomes a `[value, label, opts]` choice for
  # `RadioField`. Existing-location rows submit the location id;
  # placeholder rows are disabled (so they're inert / not submitted)
  # and `append:` a "Create" link as a sibling of the label inside
  # the `.radio` wrap — kept outside `<label>` so clicking the link
  # doesn't accidentally toggle the radio.
  def suffix_choices
    suffixes.map do |suffix|
      location = existing[suffix]
      if location
        [location.id, " #{suffix}"]
      else
        [suffix, " #{suffix}",
         { disabled: true, append: suffix_create_link(suffix) }]
      end
    end
  end

  def suffix_create_link(suffix)
    # HTML-safe string built via Rails `tag.a` (returns SafeBuffer)
    # so `RadioField` can emit it via `trusted_html`. Leading space
    # gives a small gap between the disabled label text and the link.
    " ".html_safe + helpers.tag.a(
      :form_violations_modal_target_location_create.l,
      href: new_location_path(display_name: suffix),
      target: "_blank", rel: "noopener",
      class: "btn btn-default btn-xs"
    )
  end

  def suffixes
    @suffixes ||= self.class.suffixes_for(@obs)
  end

  # Existing Locations whose name matches one of the suffixes, indexed
  # by name. Batch-loaded in a single query (Copilot review on PR #4182).
  def existing
    @existing ||= Location.where(name: suffixes).index_by(&:name)
  end

  # Pre-check the first suffix that has a Location, not the first
  # suffix overall — otherwise a modal whose most-specific suffix is
  # missing renders with no enabled radio selected by default and
  # silent submit becomes a no-op (Copilot review on PR #4182).
  def first_existing
    @first_existing ||= suffixes.find { |s| existing.key?(s) }
  end
end
