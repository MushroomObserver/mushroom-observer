# frozen_string_literal: true

# Phlex form for creating/editing projects.
# Replaces the ERB partial projects/_form.html.erb.
class Components::ProjectForm < Components::ApplicationForm
  def initialize(model, dates_any: true, upload_params: nil,
                 dirty_form: false, **)
    @dates_any = dates_any
    @upload_params = upload_params
    @dirty_form = dirty_form
    super(model, **)
  end

  # Adds the dirty-form Stimulus controller to the rendered <form>
  # tag when the caller opts in. Used on the Admin/Details tab to
  # warn the user before navigating away from unsaved changes.
  def around_template
    if @dirty_form
      @attributes[:data] ||= {}
      existing = @attributes[:data][:controller]
      @attributes[:data][:controller] =
        [existing, "dirty-form"].compact.join(" ").strip
      @attributes[:data][:action] =
        [@attributes[:data][:action],
         "submit->dirty-form#allowSubmit"].compact.join(" ").strip
    end
    super
  end

  def view_template
    super do
      submit(submit_text, center: true)
      render_open_membership
      render_title
      render_summary
      render_field_slip_prefix
      render_location
      render_dates_section
      render_upload_fields if @upload_params
    end
  end

  private

  def form_action
    return projects_path if model.nil? || !model.persisted?

    project_path(model)
  end

  def render_open_membership
    checkbox_field(:open_membership,
                   label: :form_projects_open_membership.t)
  end

  def render_title
    text_field(:title,
               label: "#{:form_projects_title.t}:",
               data: { autofocus: true })
  end

  def render_summary
    textarea_field(:summary, rows: 5,
                             label: "#{:SUMMARY.t}:") do |f|
      f.with_help { :shared_textile_help.l }
    end
  end

  def render_field_slip_prefix
    text_field(:field_slip_prefix,
               label: "#{:FIELD_SLIP_PREFIX.t}:")
  end

  def render_location
    autocompleter_field(:place_name, type: :location,
                                     label: "#{:WHERE.t}:")
  end

  def render_dates_section
    div do
      p { "*#{:form_projects_date_range.t}*".t }
      p { :form_projects_dates_explain.t }
    end
    div(class: "container-text ml-4") do
      date_field(:start_date,
                 label: "#{:form_projects_start_date.t}: ",
                 wrap_class: "mb-2")
      date_field(:end_date,
                 label: "#{:form_projects_end_date.t}: ")
      render_dates_any_radios
    end
  end

  # `dates_any` is UI state passed in from the controller, not a Project
  # attribute, so we can't use `field(:dates_any)`. FieldProxy gives RadioField
  # the field name, value, and namespace it needs without a model accessor.
  def render_dates_any_radios
    proxy = Components::ApplicationForm::FieldProxy.new(
      "project", :dates_any, @dates_any
    )
    render(Components::ApplicationForm::RadioField.new(
             proxy,
             ["false", range_label],
             ["true", any_label]
           ))
  end

  def range_label
    "#{:form_projects_range.t} " \
      "(#{:form_projects_use_date_range.t})"
  end

  def any_label
    "#{:form_projects_any.t} " \
      "(#{:form_projects_ignore_date_range.t})"
  end

  def render_upload_fields
    upload_fields(
      file_field_label: :form_projects_image_upload.l,
      copyright_holder: @upload_params[:copyright_holder],
      copyright_year: @upload_params[:copyright_year],
      licenses: @upload_params[:licenses],
      upload_license_id: @upload_params[:upload_license_id]
    )
  end

  def submit_text
    model.persisted? ? :SAVE_EDITS.l : :CREATE.l
  end
end
