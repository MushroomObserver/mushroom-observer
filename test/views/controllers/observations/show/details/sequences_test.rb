# frozen_string_literal: true

require("test_helper")

class Views::Controllers::Observations::Show::Details::SequencesTest <
  ComponentTestCase
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
    assert_html(html, "#sequence_#{sequence.id} " \
                       "button[data-clipboard-text-value='#{sequence.bases}']")
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
    Views::Controllers::Observations::Show::Details::Sequences.new(
      obs: obs, user: user, has_sibling_records: false
    )
  end
end
