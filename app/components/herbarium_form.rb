# frozen_string_literal: true

# Form for creating or editing herbaria (fungaria).
# Handles both personal and institutional herbaria with optional location
# selection via map.
class Components::HerbariumForm < Components::ApplicationForm
  # rubocop:disable Metrics/ParameterLists
  def initialize(model, user:, back: nil, location: nil, top_users: nil, **)
    @user = user
    @back = back
    @location = location
    @top_users = top_users || []
    super(model, id: "herbarium_form", **)
  end
  # rubocop:enable Metrics/ParameterLists

  def around_template
    @attributes[:data] ||= {}
    @attributes[:data][:controller] = "map"
    @attributes[:data][:map_open] = false
    @attributes[:data][:map_autocompleter__location_outlet] =
      "#herbarium_location_autocompleter"
    super
  end

  def view_template
    hidden_field(:back, value: @back) if @back
    render_name_field
    render_personal_user_field
    submit(submit_text, center: true)
    render_code_field
    render_location_section
    render_contact_fields
    render_notes_field
    submit(submit_text, center: true)
  end

  private

  def render_name_field
    text_field(:name, label: "#{:NAME.t}:") do |f|
      f.with_between { render_name_between }
    end
  end

  def render_name_between
    span(class: "help-note") { "(#{:required.l})" }
    render_personal_help if personal_herbarium?
  end

  def render_personal_help
    help_block_with_arrow("down") do
      :edit_herbarium_this_is_personal_herbarium.tp
    end
  end

  def personal_herbarium?
    model.personal_user_id == @user&.id
  end

  def render_personal_user_field
    if in_admin_mode?
      render_admin_personal_user_field
    elsif create? || model.can_make_personal?(@user)
      render_personal_checkbox
    end
  end

  def render_admin_personal_user_field
    autocompleter_field(
      :personal_user_name,
      type: :user,
      label: :edit_herbarium_admin_make_personal.t,
      help: admin_help_text,
      inline: true
    )
  end

  def admin_help_text
    return nil unless in_admin_mode? && !create?

    if @top_users.empty?
      :edit_herbarium_no_herbarium_records.l
    else
      capture { render_top_users_list }
    end
  end

  def render_top_users_list
    @top_users.each_with_index do |(name, login, count), index|
      br if index.positive?
      # rubocop:disable Rails/OutputSafety
      raw(:edit_herbarium_user_records.t(
        name: "#{name} (#{login})", num: count
      ).html_safe)
      # rubocop:enable Rails/OutputSafety
    end
  end

  def render_personal_checkbox
    checkbox_field(
      :personal,
      label: :create_herbarium_personal.l,
      help: :create_herbarium_personal_help.t(
        name: @user&.personal_herbarium_name
      )
    )
  end

  def render_code_field
    return if model.personal_user_id

    text_field(
      :code,
      label: "#{:create_herbarium_code.l}:",
      inline: true
    ) do |f|
      f.with_between { render_code_between }
    end
  end

  def render_code_between
    span(class: "help-note") do
      "(#{:create_herbarium_code_recommended.l}) "
    end
    help_block_with_arrow("down") { :create_herbarium_code_help.t }
  end

  def render_location_section
    render_location_autocompleter
    render(Components::BoundsHiddenFields.new(
             location: @location,
             target_controller: :map
           ))
  end

  def render_location_autocompleter
    autocompleter_field(
      :place_name,
      type: :location,
      label: location_label,
      between: :optional,
      controller_data: { map_target: "autocompleter" },
      controller_id: "herbarium_location_autocompleter",
      create_text: :form_observations_create_locality.l,
      map_outlet: "#herbarium_form",
      hidden_name: :location_id,
      hidden_data: { map_target: "locationId" },
      data: { map_target: "placeInput" }
    ) do |f|
      f.with_append { render_map_section }
    end
  end

  def location_label
    capture do
      span(class: "unconstrained-label") { "#{:LOCATION.l}:" }
      whitespace
      span(class: "create-label") { "#{:form_observations_create_locality.l}:" }
    end
  end

  def render_map_section
    div(class: "mb-5 d-none",
        data: { autocompleter__location_target: "mapWrap" }) do
      render(Components::FormLocationMap.new(
               id: "herbarium_form_map",
               map_type: "observation",
               user: @user
             ))
    end
  end

  def render_contact_fields
    text_field(:email, label: "#{:create_herbarium_email.l}:",
                       between: :optional)
    textarea_field(
      :mailing_address,
      label: "#{:create_herbarium_mailing_address.l}:",
      rows: 5,
      between: :optional
    )
  end

  def render_notes_field
    textarea_field(:description, label: "#{:NOTES.l}:", rows: 10,
                                 between: :optional)
  end

  def submit_text
    create? ? :CREATE.l : :SAVE.l
  end

  def create?
    model.new_record?
  end

  def form_action
    if create?
      url_for(controller: "herbaria", action: :create, only_path: true)
    else
      url_for(
        controller: "herbaria",
        action: :update,
        id: model.id,
        only_path: true
      )
    end
  end
end
