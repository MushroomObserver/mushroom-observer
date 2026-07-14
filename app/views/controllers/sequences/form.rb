# frozen_string_literal: true

module Views::Controllers::Sequences
  # Form for creating or editing DNA sequences attached to
  # observations. Sequences can contain genetic data (bases) or
  # reference external archives. Rendered directly by the sequences
  # controller's `new.rb` and `edit.rb`, and dynamically
  # by `Components::Modal::TurboForm` via `form_component_class_for`.
  class Form < ::Components::ApplicationForm
    def initialize(model, observation: nil, back: nil, **)
      @observation = observation
      @back = back
      super(model, **)
    end

    def view_template
      render_locus_field
      render_locus_help
      render_bases_field
      render_deposit_info
      render_notes_field
      render_notes_help
      submit(submit_text, center: true)
    end

    private

    def render_locus_field
      textarea_field(:locus,
                     rows: 1,
                     label: :LOCUS,
                     between: :required,
                     wrap_class: "w-100")
    end

    def render_locus_help
      Help(arrow: :up, id: "sequence_locus_help",
           content: :form_sequence_locus_help.t(
             locus_width: Sequence::LOCUS_WIDTH
           ))
    end

    def render_bases_field
      textarea_field(:bases, cols: 80, rows: 5, label: :BASES,
                             class: "font-monospace") do |f|
        f.with_between do
          Help(element: :span,
               content: "(#{:form_sequence_bases_or_deposit_required.t})")
          Link(type: :external,
               content: "(#{:form_sequence_bases_format.t})",
               path: WebSequenceArchive.blast_format_help,
               class: "d-inline-block float-right")
        end
      end
    end

    def render_deposit_info
      div(class: "form-group") { render_deposit_fields }
      render_accession_help
    end

    def render_deposit_fields
      label(for: "sequence_deposit", class: "mr-3") { :DEPOSIT.l }
      Help(element: :span, content: "(#{:form_sequence_valid_deposit.t})")
      render_archive_select
      render_accession_field
    end

    def render_archive_select
      select_field(:archive, [nil] + sequence_archive_options,
                   label: :ARCHIVE,
                   inline: true,
                   wrap_class: "ml-5")
    end

    def render_accession_field
      text_field(:accession,
                 label: :form_sequence_accession,
                 inline: true,
                 wrap_class: "ml-5")
    end

    def render_accession_help
      Help(arrow: :up, id: "sequence_accession_help",
           content: :form_sequence_accession_help.t)
    end

    def render_notes_field
      textarea_field(:notes,
                     rows: 3,
                     label: :NOTES,
                     between: :optional)
    end

    def render_notes_help
      Help(arrow: :up, id: "textile_help", content: :field_textile_link.t)
    end

    def submit_text
      model.persisted? ? :UPDATE.l : :ADD.l
    end

    def form_action
      if model.persisted?
        url_params = { action: :update, id: model.id }
        url_params[:back] = @back if @back.present?
        url_for(
          controller: "sequences",
          **url_params,
          only_path: true
        )
      else
        url_for(
          controller: "sequences",
          action: :create,
          observation_id: observation.id,
          only_path: true
        )
      end
    end

    def observation
      @observation || model.observation
    end

    # Dropdown options for the archive select: each entry is a
    # `[label, value]` pair where label == value == archive name.
    def sequence_archive_options
      ::WebSequenceArchive.archives.each_with_object([]) do |archive, array|
        array << Array.new(2, archive[:name])
      end
    end
  end
end
