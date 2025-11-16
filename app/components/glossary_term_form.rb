# frozen_string_literal: true

# Form for creating/editing glossary terms
class Components::GlossaryTermForm < Components::ApplicationForm
  def view_template(&block)
    render_locked_checkbox if in_admin_mode?
    render_name_field
    render_description_field
    yield if block
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
                      data: { autofocus: true },
                      append: name_help_text)
  end

  def render_description_field
    textarea_field(:description, label: "#{:glossary_term_description.l}:",
                                 rows: 16,
                                 append: description_help_text)
  end

  def name_help_text
    p do
      :form_glossary_name_help.t
      whitespace
      glossary_doc_link
    end
  end

  def description_help_text
    p do
      :form_glossary_description_help.t
      whitespace
      glossary_doc_link
      plain(". ")
      :field_textile_link.t
    end
  end

  def glossary_doc_link
    link_to(
      :glossary_term_index_documentation.t,
      "https://github.com/MushroomObserver/mushroom-observer/blob/main/doc/glossary.md"
    )
  end
end
