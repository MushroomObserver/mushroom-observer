# frozen_string_literal: true

# Form for creating or editing observations.
# Includes image upload, location autocomplete, naming (on create),
# specimen fields, notes, projects, and species lists.
#
# @example Usage
#   render(Components::ObservationForm.new(
#     @observation,
#     action: :create,
#     user: @user,
#     location: @location,
#     good_images: @good_images,
#     # ... other params
#   ))
#
class Components::ObservationForm < Components::ApplicationForm
  # rubocop:disable Metrics/ParameterLists, Metrics/AbcSize
  def initialize(model, mode:, user:, location: nil, good_images: [],
                 exif_data: {}, given_name: nil, place_name: nil,
                 default_place_name: nil, dubious_where_reasons: nil,
                 vote: nil, names: [], valid_names: [], reasons: nil,
                 suggest_corrections: false, parent_deprecated: nil,
                 collectors_name: nil, collectors_number: nil,
                 herbarium_name: nil, herbarium_id: nil, accession_number: nil,
                 projects: [], project_checks: {}, lists: [], list_checks: {},
                 error_checked_projects: [], suspect_checked_projects: [],
                 field_code: nil, **)
    @mode = mode
    @user = user
    @location = location
    @good_images = good_images
    @exif_data = exif_data
    @given_name = given_name
    @place_name = place_name
    @default_place_name = default_place_name
    @dubious_where_reasons = dubious_where_reasons
    @vote = vote
    @names = names
    @valid_names = valid_names
    @reasons = reasons
    @suggest_corrections = suggest_corrections
    @parent_deprecated = parent_deprecated
    @collectors_name = collectors_name
    @collectors_number = collectors_number
    @herbarium_name = herbarium_name
    @herbarium_id = herbarium_id
    @accession_number = accession_number
    @projects = projects
    @project_checks = project_checks
    @lists = lists
    @list_checks = list_checks
    @error_checked_projects = error_checked_projects
    @suspect_checked_projects = suspect_checked_projects
    @field_code = field_code
    super(model, id: "observation_form", **)
  end
  # rubocop:enable Metrics/ParameterLists, Metrics/AbcSize

  def around_template
    @attributes[:data] = form_data_attributes
    @attributes[:multipart] = true
    super
  end

  def view_template
    render_field_code if @field_code
    submit(button_name, center: true)
    render_images_details_panel
    render_naming_specimen_panel
    render_notes_panel
    render_projects_panel if show_projects?
    render_lists_panel if show_lists?
  end

  private

  # --- Configuration ---

  def create?
    @mode == :create
  end

  def button_name
    create? ? :CREATE.l : :SAVE_EDITS.l
  end

  # Override Superform's form_action to include approval query params
  # Only include these params when present (after validation warning)
  def form_action
    params = {
      controller: "observations",
      action: create? ? :create : :update,
      id: model.id,
      only_path: true
    }
    params[:approved_name] = @given_name if @given_name.present?
    params[:approved_where] = @place_name if @place_name.present?
    url_for(params)
  end

  def form_data_attributes
    {
      controller: "form-images form-exif map",
      action: "map:reenableBtns@window->form-exif#reenableButtons",
      map_autocompleter__location_outlet: "#observation_location_autocompleter",
      map_open: "false",
      form_exif_autocompleter__location_outlet:
        "#observation_location_autocompleter",
      form_exif_map_outlet: "#observation_form",
      upload_max_size: MO.image_upload_max_size.to_s,
      localization: image_upload_localization.to_json,
      form_images_target: "form",
      exif_used: (!create?).to_s
    }
  end

  def image_upload_localization
    max = (MO.image_upload_max_size.to_f / 1024 / 1024).round
    {
      uploading_text: :form_observations_uploading_images.t,
      image_too_big_text: :form_observations_image_too_big.t(max: max),
      creating_observation_text: :form_observations_creating_observation.t,
      months: :all_months.t,
      show_on_map: :show_on_map.t,
      something_went_wrong: :form_observations_upload_error.t
    }
  end

  # --- Field Code ---

  def render_field_code
    p { "#{:form_observations_field_code.t} #{@field_code}" }
    input(type: "hidden", name: "field_code", value: @field_code)
  end

  # --- Images + Details Panel ---

  def render_images_details_panel
    render(images_details_panel) do |panel|
      panel.with_heading { "#{:IMAGES.l} + #{:show_observation_details.l}" }
      render_upload_body(panel)
      render_images_body(panel)
      render_details_body(panel)
    end
  end

  def images_details_panel
    Components::Panel.new(
      panel_id: "observation_images_details",
      collapsible: true,
      collapse_target: ".observation_images_details_inner",
      expanded: true
    )
  end

  def render_upload_body(panel)
    panel.with_body(collapse: true, classes: "border-bottom",
                    id: "observation_upload") do
      ObservationFormUpload(form: self, good_images: @good_images)
    end
  end

  def render_images_body(panel)
    panel.with_body(collapse: true, classes: "p-0",
                    id: "observation_images") do
      FormCarousel(
        images: @good_images,
        exif_data: @exif_data,
        obs_thumb_id: model.thumb_image_id,
        user: @user
      )
    end
  end

  def render_details_body(panel)
    panel.with_body(collapse: true, classes: "border-top",
                    id: "observation_details") do
      ObservationFormDetails(
        form: self,
        observation: model,
        mode: @mode,
        button_name: button_name,
        location: @location,
        default_place_name: @default_place_name,
        dubious_where_reasons: @dubious_where_reasons
      )
    end
  end

  # --- Naming + Specimen Panel ---

  def render_naming_specimen_panel
    render(naming_specimen_panel) do |panel|
      panel.with_heading { "#{:IDENTIFICATION.l} + #{:SPECIMEN.l}" }
      panel.with_body(collapse: true) do
        render_name_feedback if create? && @given_name.present?
        render_naming_specimen_row
      end
    end
  end

  def naming_specimen_panel
    Components::Panel.new(
      panel_id: "observation_naming_specimen",
      collapsible: true,
      collapse_target: "#observation_naming_specimen_inner",
      expanded: create?
    )
  end

  def render_name_feedback
    FormNameFeedback(
      button_name: button_name,
      given_name: @given_name,
      names: @names,
      valid_names: @valid_names,
      suggest_corrections: @suggest_corrections,
      parent_deprecated: @parent_deprecated.presence
    )
  end

  def render_naming_specimen_row
    div(class: "row") do
      render_naming_column if create?
      render_specimen_column
    end
  end

  def render_naming_column
    div(class: "col-xs-12 col-md-6") do
      NamingFields(
        form: self,
        vote: @vote,
        given_name: @given_name || "",
        reasons: @reasons,
        show_reasons: false,
        context: "blank",
        create: true,
        name_help: :form_naming_name_help_leave_blank.t,
        unfocused: true
      )
    end
  end

  def render_specimen_column
    div(class: "col-xs-12 col-md-6") do
      ObservationFormSpecimen(
        form: self,
        observation: model,
        mode: @mode,
        collectors_name: @collectors_name,
        collectors_number: @collectors_number,
        herbarium_name: @herbarium_name,
        herbarium_id: @herbarium_id,
        accession_number: @accession_number
      )
    end
  end

  # --- Notes Panel ---

  def render_notes_panel
    ObservationFormNotes(
      form: self,
      observation: model,
      user: @user,
      mode: @mode
    )
  end

  # --- Projects Panel ---

  def show_projects?
    @projects.any? || @error_checked_projects.any? ||
      @suspect_checked_projects.any?
  end

  def render_projects_panel
    ObservationFormProjects(
      form: self,
      observation: model,
      user: @user,
      button_name: button_name,
      projects: @projects,
      project_checks: @project_checks,
      error_checked_projects: @error_checked_projects,
      suspect_checked_projects: @suspect_checked_projects
    )
  end

  # --- Species Lists Panel ---

  def show_lists?
    @lists.any?
  end

  def render_lists_panel
    ObservationFormLists(
      form: self,
      lists: @lists,
      list_checks: @list_checks
    )
  end
end
