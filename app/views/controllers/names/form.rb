# frozen_string_literal: true

# Form for creating and editing Name records.
# Rendered by `names/{new,edit}.rb`.
module Views::Controllers::Names
  class Form < ::Components::ApplicationForm
    def initialize(model, **options)
      @user = options.delete(:user)
      @name_string = options.delete(:name_string) || ""
      @misspelling = options.delete(:misspelling)
      @correct_spelling = options.delete(:correct_spelling)
      @approved_rank = options.delete(:approved_rank)
      super(model, **options) # rubocop:disable Style/SuperArguments
    end

    def view_template
      super do
        submit(button_text, center: true)

        render_approved_rank_field
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

    def render_approved_rank_field
      return unless @approved_rank

      hidden_field("approved_rank", value: @approved_rank)
    end

    def button_text
      @model.new_record? ? :CREATE.l : :SAVE_EDITS.l
    end

    def render_admin_locked_checkbox
      checkbox_field(:locked, label: :form_names_locked.l, wrap_class: "mt-3")
    end

    def render_editable_fields
      Help(content: :form_names_detailed_help.l)

      render_icn_id_field
      render_rank_and_status_fields
      render_text_name_field
      render_author_field
    end

    def render_icn_id_field
      div(class: "form-inline my-3") do
        text_field(:icn_id,
                   label: "#{:form_names_icn_id.l}:",
                   inline: true,
                   size: 8) do |f|
          f.with_append do
            Help(element: :p, content: :form_names_identifier_help.l)
          end
        end
      end
    end

    def render_rank_and_status_fields
      div(class: "form-inline my-3") do
        select_field(:rank, rank_options,
                     label: "#{:Rank.l}:",
                     wrap_class: "mr-4",
                     selected: @model.rank)

        select_field(:deprecated, status_options,
                     label: "#{:Status.l}:",
                     selected: (@model.deprecated || false).to_s)
      end
    end

    def render_text_name_field
      textarea_field(:text_name,
                     label: "#{:form_names_text_name.l}:",
                     value: @name_string,
                     rows: 1,
                     data: { autofocus: true }) do |f|
        f.with_append do
          Help(element: :p, content: :form_names_text_name_help.l)
        end
      end
    end

    def render_author_field
      textarea_field(:author,
                     label: "#{:Authority.l}:",
                     rows: 2) do |f|
        f.with_append do
          Help(element: :p, content: :form_names_author_help.l)
        end
      end
    end

    def render_locked_fields
      div(class: "mt-3 mb-3") do
        render_locked_rank_field
        render_locked_status_field
        render_locked_text_name_field
        render_locked_author_field
        Help(content: :show_name_locked.tp)
      end
    end

    def render_locked_rank_field
      read_only_field(:rank,
                      label: "#{:Rank.l}:",
                      inline: true,
                      wrap_class: "mb-0",
                      text: :"Rank_#{@model.rank.to_s.downcase}".l)
    end

    def render_locked_status_field
      read_only_field(:deprecated,
                      label: "#{:Status.l}:",
                      inline: true,
                      wrap_class: "mb-0",
                      text: @model.deprecated ? :DEPRECATED.l : :ACCEPTED.l)
    end

    def render_locked_text_name_field
      read_only_field(:text_name,
                      label: "#{:Name.l}:",
                      inline: true,
                      wrap_class: "mb-0",
                      text: @name_string,
                      value: @name_string)
    end

    def render_locked_author_field
      read_only_field(:author,
                      label: "#{:Authority.l}:",
                      inline: true,
                      wrap_class: "mb-0",
                      text: @model.author)
    end

    def render_citation_field
      textarea_field(:citation,
                     label: "#{:Citation.l}:",
                     rows: 3) do |f|
        f.with_append do
          Help(element: :p,
               content: [:form_names_citation_help.l,
                         :form_names_citation_textilize_note.l].safe_join)
        end
      end
    end

    def render_misspelling_fields
      div(class: "my-4 mx-0") do
        checkbox_field(:misspelling,
                       label: :form_names_misspelling.l,
                       checked: @misspelling)

        autocompleter_field(
          :correct_spelling,
          type: :name,
          value: @correct_spelling,
          label: "#{:form_names_misspelling_it_should_be.l}:",
          help: :form_names_misspelling_note.l,
          help_collapse: true
        )
      end
    end

    def render_notes_field
      textarea_field(:notes,
                     label: "#{:form_names_taxonomic_notes.l}:",
                     rows: 6,
                     help: :shared_textile_help.l,
                     help_collapse: true) do |f|
        f.with_between do
          div(class: "mark") { :form_names_taxonomic_notes_warning.l }
        end
      end
    end

    def rank_options
      Name.all_ranks.map { |r| [rank_as_string(r), r] }
    end

    def status_options
      # Use strings because Phlex omits value attribute for boolean false
      [[:ACCEPTED.l, "false"], [:DEPRECATED.l, "true"]]
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
end
