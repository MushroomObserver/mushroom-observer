# frozen_string_literal: true

# Form for creating or editing DNA sequences attached to observations.
# Sequences can contain genetic data (bases) or reference external archives.
class Components::SequenceForm < Components::ApplicationForm
  include Phlex::Rails::Helpers::LinkTo

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
    render(
      field(:locus).textarea(
        rows: 1,
        wrapper_options: {
          label: :LOCUS.l,
          between: :required,
          class: "w-100"
        }
      )
    )
  end

  def render_locus_help
    help_block_with_arrow("up", id: "sequence_locus_help", class: "mt-3") do
      :form_sequence_locus_help.t(locus_width: Sequence::LOCUS_WIDTH)
    end
  end

  def render_bases_field
    between_content = [
      span(class: "help-note mr-3") do
        "(#{:form_sequence_bases_or_deposit_required.t})"
      end,
      link_to(
        "(#{:form_sequence_bases_format.t})",
        WebSequenceArchive.blast_format_help,
        class: "d-inline-block float-right",
        target: "_blank", rel: "noopener"
      )
    ].join.html_safe # rubocop:disable Rails/OutputSafety

    render(
      field(:bases).textarea(
        cols: 80,
        rows: 5,
        wrapper_options: {
          label: :BASES.l,
          between: raw(between_content), # rubocop:disable Rails/OutputSafety
          class: "font-monospace"
        }
      )
    )
  end

  def render_deposit_info
    div(class: "form-group") { render_deposit_fields }
    render_accession_help
  end

  def render_deposit_fields
    label(for: "sequence_deposit", class: "mr-3") { :DEPOSIT.l }
    span(class: "help-note mr-3") do
      "(#{:form_sequence_valid_deposit.t})"
    end
    render_archive_select
    render_accession_field
  end

  def render_archive_select
    render(
      field(:archive).select(
        [nil] + sequence_archive_options,
        wrapper_options: {
          label: :ARCHIVE.l,
          inline: true,
          class: "ml-5"
        }
      )
    )
  end

  def render_accession_field
    render(
      field(:accession).text(
        wrapper_options: {
          label: :form_sequence_accession.l,
          inline: true,
          class: "ml-5"
        }
      )
    )
  end

  def render_accession_help
    help_block_with_arrow(
      "up",
      id: "sequence_accession_help",
      class: "mt-3"
    ) do
      :form_sequence_accession_help.t
    end
  end

  def render_notes_field
    render(
      field(:notes).textarea(
        rows: 3,
        wrapper_options: {
          label: :NOTES.l,
          between: :optional
        }
      )
    )
  end

  def render_notes_help
    help_block_with_arrow("up", id: "textile_help", class: "mt-3") do
      :field_textile_link.t
    end
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
end
