# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Observations::Namings
  class FormTest < ComponentTestCase
    def setup
      super
      @observation = observations(:coprinus_comatus_obs)
    end

    def test_new_form
      html = render_form(model: Naming.new, vote: Vote.new, context: "blank")

      # Form structure
      assert_html(html, "form[action*='namings']")
      assert_html(html, "form[id='obs_#{@observation.id}_naming_form']")
      assert_html(html, "input[type='hidden'][name='context']")

      # Fields
      assert_html(html, "input[name='naming[name]']")
      assert_html(html, "input[data-autocompleter--name-target='input']")
      assert_html(html, "select[name='naming[vote][value]']")
      assert_html(html, "input[name='naming[reasons][1][check]']")

      # Submit button
      assert_html(html, "input[type='submit'][value='#{:CREATE.l}']")
      assert_html(html, "input.btn.btn-default")

      # Blank context collapses fields, has blank vote option
      assert_html(
        html, "div.collapse[data-autocompleter--name-target='collapseFields']"
      )
      assert_html(html, "select[name='naming[vote][value]'] option[value='']")
    end

    def test_edit_form
      naming = namings(:coprinus_comatus_naming)
      vote = votes(:coprinus_comatus_owner_vote)
      html = render_form(model: naming, vote: vote, context: "lightbox")

      # Form structure
      assert_html(html, "form[action*='/namings/#{naming.id}']")
      assert_html(html,
                  "form[id='obs_#{@observation.id}_naming_#{naming.id}_form']")

      # Submit button
      assert_html(html, "input[type='submit'][value='#{:SAVE_EDITS.l}']")

      # Vote and reasons fields present in edit form
      assert_html(html, "select[name='naming[vote][value]']")
      assert_html(html, "input[name='naming[reasons][1][check]']")

      # Lightbox context doesn't collapse fields
      assert_html(html,
                  "div:not(.collapse)[data-autocompleter--name-target=" \
                  "'collapseFields']")

      # No blank option, vote value selected
      assert_no_html(html,
                     "select[name='naming[vote][value]'] option[value='']")
      assert_html(html, "option[selected][value='#{vote.value}']")
    end

    def test_form_with_feedback
      naming = namings(:coprinus_comatus_naming)
      html = render_form(
        model: naming,
        vote: Vote.new,
        given_name: "Unknown name",
        feedback: { names: [], valid_names: nil, parent_deprecated: nil }
      )

      assert_html(html, "#name_messages")
    end

    def test_form_with_parent_deprecated_feedback
      naming = namings(:coprinus_comatus_naming)
      html = render_form(
        model: naming,
        vote: Vote.new,
        given_name: "Some name",
        feedback: {
          names: [names(:agaricus_campestris)],
          valid_names: [names(:coprinus_comatus)],
          parent_deprecated: names(:lactarius)
        }
      )

      assert_html(html, "#name_messages")
    end

    def test_turbo_enabled_when_local_false
      html = render_form(model: Naming.new, vote: Vote.new, local: false)

      assert_html(html, "form[data-turbo='true']")
    end

    def test_turbo_omitted_when_local_true
      html = render_form(model: Naming.new, vote: Vote.new, local: true)

      assert_no_html(html, "form[data-turbo]")
    end

    # The "see matching observations reasons" link in
    # `render_sibling_reasons_note` requires three conditions: edit mode,
    # the observation belongs to an Occurrence, and at least one other
    # observation in that Occurrence has a Naming for the same name_id.
    # No existing fixture combo satisfies all three (every occurrence
    # fixture is a singleton over its observations), so we build the
    # scenario on the fly — per `test/fixtures/observations.yml`'s own
    # guidance to prefer in-test creation over one-off fixtures.
    def test_sibling_observation_link_renders_in_edit_mode
      user = users(:rolf)
      name = names(:coprinus_comatus)

      # Put the edit-target observation into a fresh Occurrence.
      occurrence = Occurrence.create!(
        user: user, primary_observation: @observation
      )
      @observation.update!(occurrence: occurrence)

      # A sibling observation in the same Occurrence, with a Naming for
      # the same Name as the one being edited — this satisfies the
      # `has_sibling_reasons` guard.
      sibling = Observation.create!(
        user: user, when: Time.zone.today, where: "Sibling Site, Earth",
        text_name: "Coprinus comatus", name: name
      )
      sibling.update!(occurrence: occurrence)
      Naming.create!(observation: sibling, user: user, name: name)

      naming = namings(:coprinus_comatus_naming)
      vote = votes(:coprinus_comatus_owner_vote)
      html = render_form(model: naming, vote: vote)

      assert_html(html,
                  "a[href='#{routes.occurrence_path(occurrence)}']",
                  text: :naming_see_matching_observations_reasons.l)
    end

    private

    # rubocop:disable Metrics/ParameterLists
    def render_form(model:, vote:, context: "lightbox", local: true,
                    given_name: "", feedback: nil)
      render(Form.new(
               model,
               observation: @observation,
               vote: vote,
               given_name: given_name,
               reasons: model.init_reasons,
               feedback: feedback,
               show_reasons: true,
               context: context,
               local: local
             ))
    end
    # rubocop:enable Metrics/ParameterLists
  end
end
