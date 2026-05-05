# frozen_string_literal: true

# Turbo modal shown when a project member clicks "Trust Settings".
# Renders three radio buttons mapped to the trust_level enum
# (no_trust / hidden_gps / editing) with a help paragraph for each
# option, pre-selected to the current trust level. Submits to the
# existing Projects::MembersController#update action via a PUT.
class Components::TrustSettingsModal < Components::Base
  MODAL_ID = "modal_trust_settings"

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

  register_value_helper :form_authenticity_token

  prop :project, Project
  prop :candidate, User
  prop :current_trust_level, String

  def view_template
    div(id: MODAL_ID, class: "modal", role: "dialog",
        aria: { labelledby: "#{MODAL_ID}_title" },
        data: { controller: "modal" }) do
      div(class: "modal-dialog", role: "document") do
        div(class: "modal-content") do
          render_header
          render_form
        end
      end
    end
  end

  private

  def render_header
    div(class: "modal-header") do
      close_button
      h4(class: "modal-title", id: "#{MODAL_ID}_title") do
        plain(:show_project_trust_settings_title.l(
                project: @project.title
              ))
      end
    end
  end

  def close_button
    button(type: :button, class: "close",
           data: { dismiss: "modal" },
           aria: { label: :CLOSE.l }) do
      span(aria: { hidden: "true" }) { "×" }
    end
  end

  def render_form
    form(action: project_member_path(
      project_id: @project.id,
      candidate: @candidate.id
    ), method: "post") do
      authenticity_token_field
      method_put_field
      target_field
      div(class: "modal-body") { render_options }
      div(class: "modal-footer") do
        render_cancel_button
        whitespace
        render_submit_button
      end
    end
  end

  def render_options
    p { plain(:trust_settings_help.l) }
    OPTIONS.each do |option|
      render_option(option)
    end
  end

  def render_option(option)
    div(class: "radio mb-2") do
      label do
        radio_input(option)
        strong { plain(" #{option[:label_key].l}") }
        div(class: "ml-4 text-muted") { plain(option[:help_key].l) }
      end
    end
  end

  def radio_input(option)
    attrs = {
      type: "radio", name: "commit",
      value: option[:commit_key].l,
      id: "trust_level_#{option[:level]}"
    }
    attrs[:checked] = "checked" if option[:level] == @current_trust_level
    input(**attrs)
  end

  def render_cancel_button
    button(type: :button, class: "btn btn-default",
           data: { dismiss: "modal" }) do
      plain(:CANCEL.l)
    end
  end

  def render_submit_button
    button(type: "submit", name: "save",
           class: "btn btn-primary") do
      plain(:trust_settings_save.l)
    end
  end

  def authenticity_token_field
    input(type: "hidden", name: "authenticity_token",
          value: form_authenticity_token)
  end

  def method_put_field
    input(type: "hidden", name: "_method", value: "put")
  end

  def target_field
    input(type: "hidden", name: "target", value: "project_index")
  end
end
