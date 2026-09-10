# frozen_string_literal: true

require("test_helper")

class Views::Controllers::Observations::Show::SpecimenPanel
  class SequencesSectionTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
      @obs = observations(:detailed_unknown_obs)
    end

    def test_renders_section_id
      html = render(panel_with(@obs))

      assert_html(html, "#observation_sequences")
    end

    def test_renders_copy_button_for_sequence_with_bases
      obs = observations(:locally_sequenced_obs)
      sequence = sequences(:local_sequence)
      html = render(panel_with(obs))

      assert_html(html, "#sequence_#{sequence.id} " \
                         "button[data-controller='clipboard']")
      assert_html(
        html,
        "#sequence_#{sequence.id} " \
        "button[data-clipboard-text-value='#{sequence.bases}']"
      )
    end

    # A sequence describes the specimen, so the panel lists the whole
    # occurrence's sequences -- a reflection's native sequences live
    # on its companion.
    def test_lists_occurrence_sibling_sequences
      obs = observations(:imported_inat_obs)
      sibling = Observation.create!(
        user: obs.user, when: obs.when, where: "Sibling, USA",
        name: obs.name
      )
      occurrence = Occurrence.create!(user: obs.user,
                                      primary_observation: sibling)
      Observation.where(id: [obs.id, sibling.id]).
        update_all(occurrence_id: occurrence.id)
      seq = sibling.sequences.create!(
        user: obs.user, locus: "ITS", bases: "ACGTACGTACGTACGT"
      )
      html = render(panel_with(obs.reload))

      assert_html(html, "#sequence_#{seq.id}")
    end

    def test_omits_copy_button_for_sequence_without_bases
      obs = observations(:genbanked_obs)
      sequence = sequences(:deposited_sequence)
      html = render(panel_with(obs))

      assert_no_html(html, "#sequence_#{sequence.id} " \
                            "button[data-controller='clipboard']")
    end

    private

    def panel_with(obs, user = @user)
      SequencesSection.new(
        obs: obs, user: user, has_sibling_records: false
      )
    end
  end
end
