# frozen_string_literal: true

# Three-radio form for setting a project member's trust level
# (`no_trust` / `hidden_gps` / `editing`). Inherits Superform so the
# `<form>` tag, CSRF token, and `_method=put` hidden field are emitted
# automatically.
#
# The radios share `name="commit"` and submit different localized
# commit-label strings (`:change_member_status_revoke_trust.l` etc.)
# as their values. `Projects::MembersController#update_trust_status`
# discriminates by `params[:commit]` string equality — that's the
# pre-existing contract this form preserves.
#
# Rendered inside a `Components::ModalTurboForm` by
# `Projects::MembersController#trust_modal`.
#
# @param candidate [User] the member whose trust level is being set
# @param project [Project] the project context (drives the PUT URL)
# @param current_trust_level [String] one of
#   `"no_trust" / "hidden_gps" / "editing"` — pre-selects the radio
class Components::TrustSettingsForm < Components::ApplicationForm
  OPTIONS = [
    { commit_key: :change_member_status_revoke_trust,
      label_key: :trust_settings_no_trust_label,
      help_key: :trust_settings_no_trust_help,
      level: "no_trust" },
    { commit_key: :change_member_hidden_gps_trust,
      label_key: :trust_settings_hidden_gps_label,
      help_key: :trust_settings_hidden_gps_help,
      level: "hidden_gps" },
    { commit_key: :change_member_editing_trust,
      label_key: :trust_settings_editing_label,
      help_key: :trust_settings_editing_help,
      level: "editing" }
  ].freeze

  def initialize(candidate, project:, current_trust_level: "no_trust", **)
    @project = project
    @current_trust_level = current_trust_level
    # Superform uses the model for `dom.id` + the `persisted?` check
    # that picks PATCH vs POST. The candidate is the natural choice
    # here — it's the user whose membership is being updated.
    super(candidate, **)
  end

  def view_template
    hidden_field("target", value: "project_index")
    render_options
    render_footer_buttons
  end

  def form_action
    project_member_path(project_id: @project.id, candidate: model.id)
  end

  private

  def render_options
    p { plain(:trust_settings_help.l) }
    field = commit_field
    render(Components::ApplicationForm::RadioField.new(
             field, *radio_choices
           ))
  end

  def commit_field
    Components::ApplicationForm::FieldProxy.new(
      nil, "commit", current_commit_value
    )
  end

  # Map current_trust_level back to the commit-label that would
  # produce it, so `RadioField`'s `option_checked?` pre-selects the
  # right radio (compares stringified field.value to each option value).
  def current_commit_value
    OPTIONS.find { |o| o[:level] == @current_trust_level }&.
      dig(:commit_key)&.
      l
  end

  def radio_choices
    OPTIONS.map do |option|
      [option[:commit_key].l, option_label(option)]
    end
  end

  # Each radio's label is bold-text + a muted help div. `capture`
  # renders the Phlex block to an html_safe string, which `RadioField`
  # emits via `trusted_html` without escaping.
  def option_label(option)
    capture do
      strong { plain(" #{option[:label_key].l}") }
      div(class: "ml-4 text-muted") { plain(option[:help_key].l) }
    end
  end

  def render_footer_buttons
    # Mirror the original modal-footer button row (right-aligned,
    # top margin) without an actual `.modal-footer` div — Modal
    # renders its own `.modal-footer` as a sibling of `.modal-body`,
    # so the form (inside `.modal-body`) can't span it.
    div(class: "text-right mt-3") do
      button(type: :button, class: "btn btn-default mr-2",
             data: { dismiss: "modal" }) do
        plain(:CANCEL.l)
      end
      # `name: "save"` overrides Superform's default `name: "commit"`
      # to avoid colliding with the radio group's own `commit` name —
      # the controller switches on params[:commit] from the radios.
      submit(
        :trust_settings_save.l,
        as: :button, name: "save", btn_class: "btn-primary"
      )
    end
  end
end
