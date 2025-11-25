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
    field(:locked).checkbox(
      wrapper_options: {
        label: :form_names_locked.l,
        wrap_class: "mt-3"
      }
    )
  end

  def render_editable_fields
    # rubocop:disable Rails/OutputSafety
    raw(help_block_component(:div, :form_names_detailed_help.l))
    # rubocop:enable Rails/OutputSafety

    render_icn_id_field
    render_rank_and_status_fields
    render_text_name_field
    render_author_field
  end

  def render_icn_id_field
    div(class: "form-inline my-3") do
      append_text = help_block_component(:p, :form_names_identifier_help.l)
      render(
        field(:icn_id).text(
          wrapper_options: {
            label: "#{:form_names_icn_id.l}:",
            inline: true,
            addon: append_text
          },
          size: 8
        )
      )
    end
  end

  def render_rank_and_status_fields
    div(class: "form-inline my-3") do
      render(
        field(:rank).select(
          rank_options,
          wrapper_options: {
            label: "#{:Rank.l}:"
          },
          selected: @model.rank || "Species"
        )
      )

      render(
        field(:deprecated).select(
          status_options,
          wrapper_options: {
            label: "#{:Status.l}:",
            wrap_class: "pl-3"
          },
          selected: @model.deprecated || false
        )
      )
    end
  end

  def render_text_name_field
    render(
      field(:text_name).text(
        wrapper_options: {
          label: "#{:form_names_text_name.l}:",
          addon: help_block_component(:p, :form_names_text_name_help.l)
        },
        value: @name_string,
        data: { autofocus: true }
      )
    )
  end

  def render_author_field
    render(
      field(:author).textarea(
        wrapper_options: {
          label: "#{:Authority.l}:",
          addon: help_block_component(:p, :form_names_author_help.l)
        },
        rows: 2
      )
    )
  end

  def render_locked_fields
    div(class: "mt-3 mb-3") do
      render_locked_rank_field
      render_locked_status_field
      render_locked_text_name_field
      render_locked_author_field
      # rubocop:disable Rails/OutputSafety
      raw(help_block_component(:div, :show_name_locked.tp))
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
          text: @model.user_real_text_name(@user)
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
    append_text = view_context.tag.p(class: "help-block") do
      :form_names_citation_help.l +
        :form_names_citation_textilize_note.l
    end

    render(
      field(:citation).textarea(
        wrapper_options: {
          label: "#{:Citation.l}:",
          addon: append_text
        },
        rows: 3
      )
    )
  end

  def render_misspelling_fields
    div(class: "my-4 mx-0") do
      render(
        field(:misspelling).checkbox(
          wrapper_options: {
            label: :form_names_misspelling.l
          },
          checked: @misspelling
        )
      )

      render(
        field(:correct_spelling).autocompleter(
          type: :name,
          value: @correct_spelling,
          wrapper_options: {
            label: "#{:form_names_misspelling_it_should_be.l}:",
            help: :form_names_misspelling_note.l
          }
        )
      )
    end
  end

  def render_notes_field
    between_text = view_context.tag.div(:form_names_taxonomic_notes_warning.l,
                                        class: "mark")

    render(
      field(:notes).textarea(
        wrapper_options: {
          label: "#{:form_names_taxonomic_notes.l}:",
          between: between_text,
          help: :shared_textile_help.l
        },
        rows: 6
      )
    )
  end

  def rank_options
    # Superform expects [value, label]
    Name.all_ranks.map { |r| [r, rank_as_string(r)] }
  end

  def status_options
    # Superform expects [value, label]
    [[false, :ACCEPTED.l], [true, :DEPRECATED.l]]
  end

  def show_misspelling_fields?
    !@misspelling.nil? && (in_admin_mode? || !@model.locked)
  end

  # rubocop:disable Rails/OutputSafety
  def help_block_component(tag_name, content)
    # Content comes from trusted locale files
    view_context.tag.send(tag_name, content.html_safe, class: "help-block")
  end
  # rubocop:enable Rails/OutputSafety

  def form_action
    url_for(action: controller_action)
  end

  def controller_action
    @model.new_record? ? :create : :update
  end
end
