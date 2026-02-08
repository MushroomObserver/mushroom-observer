# frozen_string_literal: true

# Phlex form component for downloading observations in various formats.
# Shared between observations/downloads and species_lists/downloads views.
#
# @example
#   render(Components::ObservationsDownloadForm.new(
#     query_param: q_param
#   ))
#
class Components::ObservationsDownloadForm < Components::ApplicationForm
  def initialize(query_param:, format: "raw", encoding: "UTF-8", **)
    @query_param = query_param
    form_object = FormObject::Download.new(
      format: format, encoding: encoding
    )
    super(form_object, **)
  end

  def view_template
    h3(class: "mt-5") { :species_list_download_header.l }

    render_format_section
    render_encoding_section
    render_submit_buttons
    render_print_labels_section
  end

  private

  def form_action
    observations_downloads_path(q: @query_param)
  end

  def render_format_section
    p { "#{:download_observations_format.l}:" }
    div(class: "form-group") do
      radio_field(:format, *format_options)
    end
  end

  def render_encoding_section
    p { "#{:download_observations_encoding.l}:" }
    div(class: "form-group") do
      radio_field(:encoding, *encoding_options)
    end
  end

  def render_submit_buttons
    submit(:DOWNLOAD.l)
    submit(:CANCEL.l)
  end

  def render_print_labels_section
    p(class: "mt-5") do
      "#{:download_observations_print_labels_header.l}:"
    end
    submit(:download_observations_print_labels.l)
  end

  def format_options
    options = [
      [:raw, :download_observations_raw.l],
      [:adolf, :download_observations_adolf.l],
      [:dwca, :download_observations_darwin.l],
      [:symbiota, :download_observations_symbiota.l],
      [:fundis, :download_observations_fundis.l]
    ]
    if in_admin_mode?
      options << [:mycoportal,
                  :download_observations_mycoportal.l]
      options << [:mycoportal_image_list,
                  :download_observations_mycoportal_images.l]
    end
    options
  end

  def encoding_options
    [
      ["ASCII", :download_observations_ascii.l],
      ["WINDOWS-1252", :download_observations_windows.l],
      ["UTF-8", :download_observations_utf8.l],
      ["UTF-16", :download_observations_utf16.l]
    ]
  end
end
