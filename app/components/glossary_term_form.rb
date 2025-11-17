# frozen_string_literal: true

# Form for creating/editing glossary terms
class Components::GlossaryTermForm < Components::ApplicationForm
  # Override initialize to accept upload field props (only for new form)
  def initialize(model, action: nil, upload_params: nil, **)
    @upload_params = upload_params
    super(model, action: action, **)
  end

  def view_template
    render_locked_checkbox if in_admin_mode?
    render_name_field
    render_description_field
    render_upload_fields if @upload_params
    submit(:SAVE.t, center: true)
  end

  private

  # Automatically determine action URL based on whether record is persisted
  def form_action
    return view_context.glossary_terms_path if model.nil? || !model.persisted?

    view_context.glossary_term_path(model)
  end

  def render_locked_checkbox
    checkbox_field(:locked, label: :edit_glossary_term_locked.l,
                            wrap_class: "mt-3")
  end

  def render_name_field
    text_field(:name, label: "#{:glossary_term_name.l}:",
                      data: { autofocus: true }) do |f|
      f.with_append do
        p do
          plain(:form_glossary_name_help.l)
          whitespace
          glossary_doc_link
        end
      end
    end
  end

  def render_description_field
    textarea_field(:description, label: "#{:glossary_term_description.l}:",
                                 rows: 16) do |f|
      f.with_append do
        p do
          plain(:form_glossary_description_help.l)
          whitespace
          glossary_doc_link
          plain(". ")
          raw(:field_textile_link.t) # rubocop:disable Rails/OutputSafety
        end
      end
    end
  end

  def glossary_doc_link
    link_to(
      :glossary_term_index_documentation.t,
      "https://github.com/MushroomObserver/mushroom-observer/blob/main/doc/glossary.md"
    )
  end

  def render_upload_fields
    upload_fields(
      copyright_holder: @upload_params[:copyright_holder],
      copyright_year: @upload_params[:copyright_year],
      licenses: @upload_params[:licenses],
      upload_license_id: @upload_params[:upload_license_id]
    )
  end
end
