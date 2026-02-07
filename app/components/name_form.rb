# frozen_string_literal: true

# Form for creating and editing Name records
class Components::NameForm < Components::ApplicationForm
  def initialize(model, **options)
    @user = options.delete(:user)
    @name_string = options.delete(:name_string) || ""
    @misspelling = options.delete(:misspelling)
    @correct_spelling = options.delete(:correct_spelling)
    super(model, **options) # rubocop:disable Style/SuperArguments
  end

  def view_template
    super do
      submit(button_text, center: true)

      render_admin_locked_checkbox if in_admin_mode?

      if !@model.locked || in_admin_mode?
        render_editable_fields
      else
        render_locked_fields
      end

      render_citation_field
      render_misspelling_fields if show_misspelling_fields?
      render_notes_field

      submit(button_text, center: true)
    end
  end

  private

  def button_text
    @model.new_record? ? :CREATE.l : :SAVE_EDITS.l
  end

  def render_admin_locked_checkbox
    checkbox_field(:locked, label: :form_names_locked.l, wrap_class: "mt-3")
  end

  def render_editable_fields
    div(class: "help-block") { :form_names_detailed_help.l }

    render_icn_id_field
    render_rank_and_status_fields
    render_text_name_field
    render_author_field
  end

  def render_icn_id_field
    div(class: "form-inline my-3") do
      icn_field = field(:icn_id).text(
        wrapper_options: {
          label: "#{:form_names_icn_id.l}:",
          inline: true
        },
        size: 8
      )
      icn_field.with_append do
        p(class: "help-block") { :form_names_identifier_help.l }
      end
      render(icn_field)
    end
  end

  def render_rank_and_status_fields
    div(class: "form-inline my-3") do
      render(
        field(:rank).select(
          rank_options,
          wrapper_options: {
            label: "#{:Rank.l}:",
            wrap_class: "mr-4"
          },
          selected: @model.rank
        )
      )

      render(
        field(:deprecated).select(
          status_options,
          wrapper_options: { label: "#{:Status.l}:" },
          selected: (@model.deprecated || false).to_s
        )
      )
    end
  end

  def render_text_name_field
    text_name_field = field(:text_name).textarea(
      wrapper_options: { label: "#{:form_names_text_name.l}:" },
      value: @name_string,
      rows: 1,
      data: { autofocus: true }
    )
    text_name_field.with_append do
      p(class: "help-block") { :form_names_text_name_help.l }
    end
    render(text_name_field)
  end

  def render_author_field
    author_field = field(:author).textarea(
      wrapper_options: { label: "#{:Authority.l}:" },
      rows: 2
    )
    author_field.with_append do
      p(class: "help-block") { :form_names_author_help.l }
    end
    render(author_field)
  end

  def render_locked_fields
    div(class: "mt-3 mb-3") do
      render_locked_rank_field
      render_locked_status_field
      render_locked_text_name_field
      render_locked_author_field
      # rubocop:disable Rails/OutputSafety
      div(class: "help-block") { raw(:show_name_locked.tp) }
      # rubocop:enable Rails/OutputSafety
    end
  end

  def render_locked_rank_field
    render(
      field(:rank).hidden(
        wrapper_options: {
          label: "#{:Rank.l}:",
          inline: true,
          wrap_class: "mb-0",
          text: :"Rank_#{@model.rank.to_s.downcase}".l
        }
      )
    )
  end

  def render_locked_status_field
    render(
      field(:deprecated).hidden(
        wrapper_options: {
          label: "#{:Status.l}:",
          inline: true,
          wrap_class: "mb-0",
          text: @model.deprecated ? :DEPRECATED.l : :ACCEPTED.l
        }
      )
    )
  end

  def render_locked_text_name_field
    render(
      field(:text_name).hidden(
        wrapper_options: {
          label: "#{:Name.l}:",
          inline: true,
          wrap_class: "mb-0",
          text: @name_string
        },
        value: @name_string
      )
    )
  end

  def render_locked_author_field
    render(
      field(:author).hidden(
        wrapper_options: {
          label: "#{:Authority.l}:",
          inline: true,
          wrap_class: "mb-0",
          text: @model.author
        }
      )
    )
  end

  def render_citation_field
    citation_field = field(:citation).textarea(
      wrapper_options: { label: "#{:Citation.l}:" },
      rows: 3
    )
    citation_field.with_append do
      # rubocop:disable Rails/OutputSafety
      p(class: "help-block") do
        raw(:form_names_citation_help.l)
        raw(:form_names_citation_textilize_note.l)
      end
      # rubocop:enable Rails/OutputSafety
    end
    render(citation_field)
  end

  def render_misspelling_fields
    div(class: "my-4 mx-0") do
      checkbox_field(:misspelling,
                     label: :form_names_misspelling.l,
                     checked: @misspelling)

      correct_spelling_field = field(:correct_spelling).autocompleter(
        type: :name,
        value: @correct_spelling,
        wrapper_options: { label: "#{:form_names_misspelling_it_should_be.l}:" }
      )
      correct_spelling_field.with_help { :form_names_misspelling_note.l }
      render(correct_spelling_field)
    end
  end

  def render_notes_field
    notes_field = field(:notes).textarea(
      wrapper_options: { label: "#{:form_names_taxonomic_notes.l}:" },
      rows: 6
    )
    notes_field.with_help { :shared_textile_help.l }
    notes_field.with_between do
      div(class: "mark") { :form_names_taxonomic_notes_warning.l }
    end
    render(notes_field)
  end

  def rank_options
    # Superform expects [value, label]
    Name.all_ranks.map { |r| [r, rank_as_string(r)] }
  end

  def status_options
    # Superform expects [value, label]
    # Use strings because Phlex omits value attribute for boolean false
    [["false", :ACCEPTED.l], ["true", :DEPRECATED.l]]
  end

  def show_misspelling_fields?
    !@misspelling.nil? && (in_admin_mode? || !@model.locked)
  end

  def form_action
    if @model.new_record?
      names_path
    else
      name_path(@model)
    end
  end
end
