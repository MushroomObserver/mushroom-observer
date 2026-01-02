# frozen_string_literal: true

# Form for creating or editing project aliases.
# Project aliases map short names to Users or Locations for field slip forms.
#
# Uses a type-switch controller to show/hide the appropriate autocompleter
# based on the target_type select value.
class Components::ProjectAliasForm < Components::ApplicationForm
  def initialize(model, user:, **)
    @user = user
    super(model, id: "project_alias_form", **)
  end

  def around_template
    @attributes[:data] ||= {}
    @attributes[:data][:controller] = "type-switch"
    super
  end

  def view_template
    render_errors if model.errors.any?
    render_name_field
    hidden_field(:project_id)
    render_target_type_select
    render_user_autocompleter
    render_location_autocompleter
    submit(submit_text, class: "mb-5")
  end

  private

  def render_errors
    Alert(level: :danger, id: "error_explanation") do
      h2 { error_count_message }
      ul do
        model.errors.full_messages.each do |message|
          li { message }
        end
      end
    end
  end

  def error_count_message
    count = model.errors.count
    "#{count} #{count == 1 ? "error" : "errors"} prohibited this " \
      "project alias from being saved:"
  end

  def render_name_field
    text_field(:name, label: "#{:Name.t}:", inline: true)
  end

  def render_target_type_select
    select_field(
      :target_type,
      target_type_options,
      label: "#{:project_alias_type.t}:",
      inline: true,
      data: {
        type_switch_target: "select",
        action: "type-switch#switch"
      }
    )
  end

  def target_type_options
    [
      ["user", :USER.l],
      ["location", :LOCATION.l]
    ]
  end

  def render_user_autocompleter
    div(class: panel_class("user"),
        data: { type_switch_target: "panel", type_switch_type: "user" }) do
      autocompleter_field(
        :term,
        type: :user,
        label: "#{:USER.l}:",
        value: user_term_value,
        hidden_name: :user_id,
        hidden_value: user_hidden_value
      )
    end
  end

  def render_location_autocompleter
    div(class: panel_class("location"),
        data: { type_switch_target: "panel", type_switch_type: "location" }) do
      autocompleter_field(
        :term,
        type: :location,
        label: "#{:LOCATION.l}:",
        value: location_term_value,
        hidden_name: :location_id,
        hidden_value: location_hidden_value
      )
    end
  end

  def panel_class(type)
    current_type == type ? "" : "d-none"
  end

  def current_type
    (model.target_type || "location").downcase
  end

  def user_term_value
    return "" unless model.target_type == "User"

    model.target&.format_name || ""
  end

  def location_term_value
    return "" unless model.target_type == "Location"

    model.target&.format_name || ""
  end

  def user_hidden_value
    model.target_type == "User" ? model.target_id : nil
  end

  def location_hidden_value
    model.target_type == "Location" ? model.target_id : nil
  end

  def submit_text
    if model.new_record?
      :create_object.t(type: :project_alias)
    else
      :SAVE.l
    end
  end

  def form_action
    if model.new_record?
      url_for(controller: "projects/aliases", action: :create,
              project_id: model.project_id, only_path: true)
    else
      url_for(controller: "projects/aliases", action: :update,
              project_id: model.project_id, id: model.id, only_path: true)
    end
  end
end
