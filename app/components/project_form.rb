# frozen_string_literal: true

# Phlex form for creating/editing projects.
# Replaces the ERB partial projects/_form.html.erb.
class Components::ProjectForm < Components::ApplicationForm
  def initialize(model, dates_any: true, upload_params: nil, **)
    @dates_any = dates_any
    @upload_params = upload_params
    super(model, **)
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

  def render_dates_any_radios
    render_radio("false", !@dates_any, range_label)
    render_radio("true", @dates_any, any_label)
  end

  def render_radio(value, checked, label_text)
    div(class: "radio") do
      label do
        input(type: :radio,
              name: "project[dates_any]",
              id: "project_dates_any_#{value}",
              value: value,
              checked: checked)
        whitespace
        plain(label_text)
      end
    end
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
