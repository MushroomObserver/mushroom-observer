# frozen_string_literal: true

# "Specimen" panel on the observation show page (and the naming
# propose/edit pages) — specimen-available status, plus the
# collection-numbers / herbarium-records / sequences sections. The
# first line of the body says whether a specimen is actually
# recorded. Renders right below the Details panel.
class Views::Controllers::Observations::Show::SpecimenPanel < Views::Base
  include SiblingRecords

  prop :obs, ::Observation
  prop :user, _Nilable(::User), default: nil
  prop :siblings, _Array(::Observation), default: -> { [] }

  def view_template
    Panel(panel_id: "observation_specimen") do |panel|
      panel.with_heading { :SPECIMEN.l }
      panel.with_body { render_body }
    end
  end

  private

  def specimen?
    @obs.occurrence&.has_specimen || @obs.specimen
  end

  def render_body
    render_specimen_line
    render_collection_numbers
    render_herbarium_records
    render_sequences
  end

  def render_specimen_line
    p(class: "obs-specimen", id: "observation_specimen_available") do
      if specimen?
        plain(:show_observation_specimen_available.t)
      else
        plain(:show_observation_specimen_not_available.t)
      end
    end
  end

  def render_collection_numbers
    render(CollectionNumbersSection.new(
             obs: @obs, user: @user,
             has_sibling_records: sibling_has?(:collection_numbers)
           ))
    render_sibling_records(:collection_numbers) do |cn, sib|
      a(href: collection_number_path(cn.id)) do
        trusted_html(cn.format_name)
      end
      whitespace
      sibling_attribution(sib)
    end
  end

  def render_herbarium_records
    render(HerbariumRecordsSection.new(
             obs: @obs, user: @user,
             has_sibling_records: sibling_has?(:herbarium_records)
           ))
    render_sibling_records(:herbarium_records) do |hr, sib|
      render_sibling_herbarium_record(hr, sib)
    end
  end

  def render_sequences
    render(SequencesSection.new(
             obs: @obs, user: @user,
             has_sibling_records: sibling_has?(:sequences)
           ))
    render_sibling_records(:sequences) do |seq, sib|
      a(href: sequence_path(seq.id)) { trusted_html(seq.format_name) }
      render_sibling_sequence_archive(seq) if seq.deposit?
      whitespace
      sibling_attribution(sib)
    end
  end

  def sibling_has?(association)
    @siblings.any? { |s| s.send(association).any? }
  end
end
