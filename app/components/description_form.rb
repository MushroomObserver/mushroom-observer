# frozen_string_literal: true

# Polymorphic form for creating/editing Name and Location descriptions.
# Handles source type, permissions, license, and model-specific note fields.
class Components::DescriptionForm < Components::ApplicationForm
  def initialize(description, licenses:, user:, merge_opts: {}, **)
    @description = description
    @licenses = licenses
    @user = user
    @merge = merge_opts[:merge] || false
    @old_desc_id = merge_opts[:old_desc_id]
    @delete_after = merge_opts[:delete_after]
    # Pass type-specific form ID (e.g., "name_description_form")
    super(description, id: "#{model_type}_description_form", **)
  end

  def view_template
    div(class: "container-text") do
      submit(submit_button_text.l, center: true)
      render_source_fields
      render_permissions_fields
      render_license_field
      render_description_header
      render_note_fields
      submit(submit_button_text.l, center: true)
      render_merge_fields if @merge
    end
  end

  private

  # --- Source fields ---

  def render_source_fields
    div(class: "form-group mt-3") do
      label(for: "description_source") { "#{:form_description_source.l}:" }
      render_source_type_field
      render_source_name_field
      hidden_field(:project_id)
      render_source_help if need_source_help?
    end
  end

  def render_source_type_field
    if root?
      select_field(:source_type, source_type_options_all,
                   class: "form-control")
    elsif new_record? && basic_source_type?
      select_field(:source_type, source_type_options_basic,
                   class: "form-control")
    else
      hidden_field(:source_type)
      plain(" #{source_type_label}")
    end
  end

  def render_source_name_field
    if !root? && locked_source_type?
      hidden_field(:source_name)
      plain(" #{@description.source_name.t}")
    else
      text_field(:source_name, class: "form-control")
    end
  end

  def render_source_help
    help_block(:div, :form_description_source_help.tpl)
  end

  # --- Permissions fields ---

  # Only admins and authors can see the permission checkboxes.
  # Regular writers (who can edit text) don't see these fields at all.
  def render_permissions_fields
    return unless show_permissions?

    div(class: "form-group") do
      b { "#{:form_description_permissions.l}:" }
      checkbox_field(:public_write, label: :form_description_public_writable.l,
                                    disabled: permissions_disabled?)
      checkbox_field(:public, label: :form_description_public_readable.l,
                              disabled: permissions_disabled?)
      help_block(:p, :form_description_permissions_help.t)
    end
  end

  def show_permissions?
    root? || admin? || author? || owner?
  end

  # --- License field ---

  def render_license_field
    select_field(:license_id, license_options, label: "#{:License.l}:") do
      help_block(:p, :form_description_license_help.t)
    end
  end

  def license_options
    # @licenses comes as [[label, id], ...] from License.available_names_and_ids
    # Superform expects [[value, label], ...]
    @licenses.map { |label, id| [id, label] }
  end

  # --- Note fields ---

  def render_description_header
    if name_description?
      p { b { :DESCRIPTION.t } }
      help_block(:div, :shared_textile_help.l, id: "textilize_note")
    else
      hr
    end
  end

  def render_note_fields
    model.class.all_note_fields.each do |field|
      textarea_field(field, label: field_label(field), rows: 10) do
        help_block(:div, field_help(field))
      end
    end
    return if name_description?

    help_block(:div, :shared_textile_help.t, id: "textilize_note")
  end

  def field_label(field)
    "#{:"form_#{model_prefix}_#{field}".l}:"
  end

  def field_help(field)
    if name_description?
      :"form_names_#{field}_help".t(rank: rank_string)
    else
      :"form_locations_#{field}_help".t
    end
  end

  # --- Merge fields ---

  def render_merge_fields
    input(type: "hidden", name: "old_desc_id", value: @old_desc_id)
    input(type: "hidden", name: "delete_after", value: @delete_after)
  end

  # --- Helper methods ---

  # Override Superform's key method to use a common namespace for all
  # description types. This ensures field names like "description[source_type]"
  # and IDs like "description_source_type" regardless of model type.
  def key
    "description"
  end

  def name_description?
    @description.is_a?(NameDescription)
  end

  def model_type
    name_description? ? "name" : "location"
  end

  def model_prefix
    "#{model_type}s"
  end

  def rank_string
    return "" unless name_description?

    rank = @description.parent&.rank
    rank.to_s.downcase
  end

  def new_record?
    @description.new_record?
  end

  def admin?
    new_record? || @description.is_admin?(@user)
  end

  def author?
    new_record? || @description.author?(@user)
  end

  def owner?
    @description.user == @user
  end

  def root?
    in_admin_mode?
  end

  def source_type
    @description.source_type.to_s
  end

  def basic_source_type?
    %w[public source user].include?(source_type)
  end

  def locked_source_type?
    %w[foreign project].include?(source_type)
  end

  def need_source_help?
    !root? && new_record? && basic_source_type?
  end

  def permissions_disabled?
    %w[public foreign].include?(source_type) && !root? && !new_record?
  end

  def source_type_label
    :"form_description_source_#{source_type}".l
  end

  def source_type_options_all
    Description::ALL_SOURCE_TYPES.map do |type|
      [type, :"form_description_source_#{type}".l]
    end
  end

  def source_type_options_basic
    Description::BASIC_SOURCE_TYPES.map do |type|
      [type, :"form_description_source_#{type}".l]
    end
  end

  def submit_button_text
    new_record? ? :CREATE : :SAVE_EDITS
  end

  def form_action
    url_for(form_action_params.merge(only_path: true))
  end

  def form_action_params
    if name_description? && new_record?
      { controller: "/names/descriptions", action: :create,
        name_id: @description.name_id }
    elsif name_description?
      { controller: "/names/descriptions", action: :update,
        id: @description.id }
    elsif new_record?
      { controller: "/locations/descriptions", action: :create,
        location_id: @description.location_id }
    else
      { controller: "/locations/descriptions", action: :update,
        id: @description.id }
    end
  end
end
