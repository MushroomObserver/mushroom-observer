# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Observations
  class FormTest < ComponentTestCase
    def test_new_form_posts_to_observations
      user = users(:rolf)
      obs = Observation.new(when: Time.zone.today)

      html = render_form(observation: obs, user: user, mode: :create)

      # Should post to /observations (no query params on initial load)
      assert_html(html, "form[action='/observations'][method='post']")
    end

    def test_form_includes_approval_params_when_present
      user = users(:rolf)
      obs = Observation.new(when: Time.zone.today)

      html = render_form(
        observation: obs,
        user: user,
        mode: :create,
        given_name: "Agaricus",
        place_name: "California"
      )

      # Form action should include approval query params
      assert_html(html, "form[action*='approved_name=Agaricus']")
      assert_html(html, "form[action*='approved_where=California']")
    end

    def test_place_name_input_has_map_target
      user = users(:rolf)
      obs = Observation.new(when: Time.zone.today)

      html = render_form(observation: obs, user: user, mode: :create)

      # The place_name input should have data-map-target="placeInput"
      # to enable the map controller to clear it
      assert_html(html, "input[name='observation[place_name]']" \
                        "[data-map-target='placeInput']")
    end

    def test_file_input_has_accept_attribute
      user = users(:rolf)
      obs = Observation.new(when: Time.zone.today)

      html = render_form(observation: obs, user: user, mode: :create)

      # File input should restrict to images to prevent folder selection errors
      assert_html(html, "input[type='file'][accept='image/*']")
    end

    # --- Field Slip Code ---

    def test_new_form_shows_editable_field_slip_code
      user = users(:rolf)
      obs = Observation.new(when: Time.zone.today)

      html = render_form(observation: obs, user: user, mode: :create)

      assert_html(html, "input[name='field_code'][type='text']")
      assert_no_html(html, "input[name='field_code'][type='hidden']")
    end

    # A code supplied by the URL (a QR scan) is prefilled but still
    # editable, so a mis-scan can be corrected on the form. There is no
    # longer a locked/static variant. See #4932.
    def test_new_form_prefilled_field_code_stays_editable
      user = users(:rolf)
      obs = Observation.new(when: Time.zone.today)

      html = render_form(observation: obs, user: user, mode: :create,
                         field_code: "NEMF-1234")

      assert_html(html, "input[name='field_code'][type='text']" \
                        "[value='NEMF-1234']")
      assert_no_html(html, "input[name='field_code'][type='hidden']")
      assert_no_html(html, "input[name='field_code_locked']")
    end

    # --- Field Slip Notes ---

    # With a field code in play the form grows the slip's standard
    # headings, so slip data has somewhere to go. Without one it doesn't.
    def test_field_code_adds_field_slip_note_headings
      user = users(:rolf)
      user.update!(notes_template: "")
      obs = Observation.new(when: Time.zone.today)

      html = render_form(observation: obs, user: user, mode: :create,
                         field_code: "NEMF-1234")

      FieldSlip::NOTE_HEADINGS.each do |heading|
        assert_html(html, "textarea[name='observation[notes][#{heading}]']")
      end

      plain = render_form(observation: obs, user: user, mode: :create)

      assert_no_html(plain, "textarea[name='observation[notes][Substrate]']")
      assert_html(plain, "textarea[name='observation[notes][Other]']")
    end

    # A heading the user already has in their notes_template renders once,
    # in the template's position — not a second time from the slip set.
    def test_templated_heading_is_not_duplicated_by_field_slip
      user = users(:rolf)
      user.update!(notes_template: "Substrate")
      obs = Observation.new(when: Time.zone.today)

      html = render_form(observation: obs, user: user, mode: :create,
                         field_code: "NEMF-1234")

      assert_html(html, "textarea[name='observation[notes][Substrate]']",
                  count: 1)
    end

    def test_edit_form_shows_field_slip_code_from_model
      user = users(:rolf)
      obs = observations(:minimal_unknown_obs)
      fs = field_slips(:field_slip_no_obs)
      obs.update!(occurrence: nil)
      obs.field_slip = fs
      obs.save!

      html = render_form(observation: obs, user: user, mode: :update)

      assert_html(html, "input[name='field_code'][type='text']" \
                        "[value='#{fs.code}']")
    end

    def test_edit_form_shows_empty_field_code_without_slip
      user = users(:rolf)
      obs = observations(:minimal_unknown_obs)
      obs.update!(occurrence: nil)

      html = render_form(observation: obs, user: user, mode: :update)

      assert_html(html, "input[name='field_code'][type='text']")
    end

    # #4136: per-project warning annotation lists the violation kinds
    # that apply to this obs against this project, not the project's
    # date/location *settings* (which are uninformative when the project
    # only has target_names / target_locations).
    def test_constraint_warning_lists_violation_kinds_per_project
      user = users(:rolf)
      proj = projects(:rare_fungi_project)
      proj.project_target_names.destroy_all
      proj.project_target_locations.destroy_all
      proj.update!(start_date: nil, end_date: nil, location: nil)
      proj.add_target_name(names(:agaricus))
      proj.add_target_location(locations(:burbank))
      obs = observations(:falmouth_2023_09_obs) # Boletus, Falmouth — neither

      obs.project_ids = [proj.id]
      html = render_form(
        observation: obs, user: user, mode: :update,
        projects: [proj],
        suspect_checked_projects: [proj]
      )

      assert_includes(html, :form_observations_projects_out_of_range.l)
      assert_includes(html, proj.title)
      assert_includes(html, :form_observations_projects_kind_target_name.l)
      assert_includes(html, :form_observations_projects_kind_target_location.l)
      # Old-style "(Dates: Any; Location: )" annotation should be gone.
      assert_no_match(/Dates: Any/, html)
      # Help text reflects the new wording.
      assert_includes(
        html,
        "Change the observation to align with project requirements"
      )
    end

    def test_collector_field_is_user_autocompleter
      user = users(:rolf)
      obs = Observation.new(when: Time.zone.today)

      html = render_form(observation: obs, user: user, mode: :create)

      # Collector is a user autocompleter: selecting a suggestion links a
      # User; the hidden field carries the chosen collector_user_id.
      assert_html(
        html,
        ".autocompleter[data-controller~='autocompleter--user'] " \
        "input[name='observation[collector]']"
      )
      assert_html(
        html,
        "input[type='hidden'][name='observation[collector_user_id]']"
      )
    end

    def test_edit_form_prefills_linked_collector
      user = users(:rolf)
      obs = observations(:minimal_unknown_obs)
      obs.update_columns(collector: rolf.unique_text_name,
                         collector_user_id: rolf.id)

      html = render_form(observation: obs, user: user, mode: :update)

      assert_html(
        html,
        "input[name='observation[collector]'][value='#{rolf.unique_text_name}']"
      )
      assert_html(
        html,
        "input[type='hidden'][name='observation[collector_user_id]']" \
        "[value='#{rolf.id}']"
      )
    end

    private

    def rolf = users(:rolf)

    def render_form(observation:, user:, mode: :create, **extras)
      render(Form.new(
               observation,
               mode: mode,
               user: user,
               good_images: [],
               exif_data: {},
               projects: [],
               lists: [],
               error_checked_projects: [],
               suspect_checked_projects: [],
               **extras
             ))
    end
  end
end
