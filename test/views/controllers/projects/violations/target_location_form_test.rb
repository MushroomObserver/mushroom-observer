# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Projects::Violations
  # Tests for TargetLocationForm (extracted from
  # Views::Controllers::Projects::Violations::Form in #4XXX). Covers the form's
  # isolated behavior — modal-body/footer structure, namespaced field
  # names, suffix computation, and the per-row choice/append behavior.
  # Integration with ProjectViolationsForm is covered by that
  # component's own test file.
  class TargetLocationFormTest < ComponentTestCase
    def setup
      super
      @project = projects(:falmouth_2023_09_project)
      @obs = observations(:falmouth_2023_09_obs)
    end

    # ---------- class-level helpers ----------

    def test_comma_suffixes_includes_full_name
      # Regression for J1 of PR #4182 review: a 2-part location like
      # "California, USA" must yield the full name as a candidate. The
      # earlier `(1..)` range produced an empty list after the
      # bare-country filter and the modal showed "Use Exclude instead",
      # which made no sense for a state-level target.
      assert_equal(
        ["California, USA", "USA"],
        TargetLocationForm.comma_suffixes("California, USA")
      )
      assert_equal(
        ["Berkeley, Alameda Co., California, USA",
         "Alameda Co., California, USA",
         "California, USA", "USA"],
        TargetLocationForm.comma_suffixes(
          "Berkeley, Alameda Co., California, USA"
        )
      )
      assert_equal([], TargetLocationForm.comma_suffixes(""))
      assert_equal(["USA"],
                   TargetLocationForm.comma_suffixes("USA"))
    end

    def test_suffixes_for_filters_bare_country
      # `suffixes_for` runs `comma_suffixes` then drops any suffix that
      # is a bare country name — so "California, USA" yields just
      # `["California, USA"]` (the bare "USA" tail is filtered).
      obs = mock_obs(where: "California, USA")
      assert_equal(["California, USA"],
                   TargetLocationForm.suffixes_for(obs))
    end

    def test_suffixes_for_returns_empty_for_country_only_where
      obs = mock_obs(where: "USA")
      assert_equal([], TargetLocationForm.suffixes_for(obs))
    end

    def test_suffixes_for_returns_empty_for_blank_where
      obs = mock_obs(where: "")
      assert_equal([], TargetLocationForm.suffixes_for(obs))
    end

    def test_applicable_true_when_suffixes_exist
      obs = mock_obs(where: "Berkeley, California, USA")
      assert(TargetLocationForm.applicable?(obs))
    end

    def test_applicable_false_when_no_suffixes
      obs = mock_obs(where: "USA")
      assert_not(TargetLocationForm.applicable?(obs))
    end

    def test_owns_modal_sections_class_method_returns_true
      # Modal's :form_content slot pattern — callers (Project's modal
      # wrapper) auto-detect this to switch slots.
      assert(TargetLocationForm.owns_modal_sections?)
    end

    # ---------- view_template structure ----------

    def test_form_wraps_modal_body_and_modal_footer
      html = render_form

      # The form spans both modal sections — submit in .modal-footer is
      # naturally inside the form (Modal :form_content slot pattern).
      assert_html(html, "form > .modal-body")
      assert_html(html, "form > .modal-footer")
      assert_html(html, "form > .modal-footer button[type='submit']")
      assert_html(html,
                  "form > .modal-footer button[type='button']" \
                  "[data-dismiss='modal']")
    end

    def test_form_action_is_violations_path_with_patch_method
      html = render_form

      expected_action = "/projects/#{@project.id}/violations"
      assert_html(html,
                  "form[action='#{expected_action}'][method='post']")
      # Superform picks PATCH for the persisted Project model. The route
      # accepts both PATCH and PUT — see config/routes.rb where
      # `project_violations_update` is registered with
      # `via: [:put, :patch]`.
      assert_html(html,
                  "input[type='hidden'][name='_method'][value='patch']")
    end

    def test_hidden_do_and_obs_id_fields_are_namespaced_under_project
      # All action params live under `project[...]` — the Project is the
      # Superform model, so Superform auto-namespaces. The controller
      # reads `params.dig(:project, :do)`, `params.dig(:project, :obs_id)`.
      html = render_form

      assert_html(html,
                  "input[type='hidden'][name='project[do]']" \
                  "[value='add_target_location']")
      assert_html(html,
                  "input[type='hidden'][name='project[obs_id]']" \
                  "[value='#{@obs.id}']")
    end

    def test_location_id_radio_is_namespaced_under_project
      # Same namespacing for the radio (location_id) — the FieldProxy
      # derives its `name` attribute from `field(:location_id).dom.name`
      # so the radio submits as `project[location_id]`.
      html = render_form

      assert_html(html,
                  "input[type='radio'][name='project[location_id]']")
    end

    # ---------- body contents ----------

    def test_help_paragraph_renders_inside_modal_body
      html = render_form
      assert_html(html, ".modal-body > p",
                  text: :form_violations_modal_target_location_help.l)
    end

    def test_renders_one_radio_per_suffix
      html = render_form

      expected_count = TargetLocationForm.suffixes_for(@obs).size
      selector = ".modal-body input[type='radio']" \
                 "[name='project[location_id]']"
      assert_html(html, selector, count: expected_count)
    end

    # ---------- footer buttons ----------

    def test_footer_has_submit_and_cancel_buttons
      html = render_form
      assert_html(html,
                  ".modal-footer button[type='submit']",
                  text: :form_violations_modal_target_location_submit.l)
      assert_html(html,
                  ".modal-footer button[type='button'][data-dismiss='modal']",
                  text: :cancel.ti)
    end

    # ---------- per-radio Create link (#4304) ----------

    def test_existing_suffix_renders_enabled_radio_with_location_id
      # Setup an obs whose location's name has an existing-Location
      # suffix — the full location name itself is the easiest match,
      # since the obs's location exists by definition.
      html = render_form

      assert_html(html,
                  "input[type='radio']" \
                  "[name='project[location_id]']" \
                  "[value='#{@obs.location.id}']:not([disabled])")
      # And no Create link sits on this row (it's the existing-row
      # branch — the Create link is only `append:`-ed to disabled
      # missing-suffix radios).
      assert_no_html(html,
                     "label:has(input[value='#{@obs.location.id}']) " \
                     "a[target='_blank']")
    end

    def test_missing_suffix_renders_disabled_radio_and_create_link
      # Use a synthetic obs whose `where` has suffixes that aren't in
      # the Locations table — guarantees the disabled-with-Create-link
      # branch fires regardless of which Locations happen to exist.
      obs = Observation.create!(
        user: @project.user,
        where: "Made-up Place, MadeUpCounty, California, USA",
        when: Time.zone.today,
        name: Name.unknown
      )

      html = render(TargetLocationForm.new(
                      obs: obs, project: @project,
                      existing_locations: existing_for(obs)
                    ))

      assert_html(html, "input[type='radio'][disabled]")

      # Create link uses ?where=<suffix> (not display_name=), opens in
      # a new tab, AND dismisses the parent modal via
      # data-action="click->modal#hide" — these together let the admin
      # create the missing Location and see the radio enabled on next
      # "Add Target Location" click without a page reload. The link
      # lives INSIDE the disabled radio's `.radio` div (per-row
      # append), not as a sibling above the radio group.
      #
      # `data-action` is used in place of Bootstrap's `data-dismiss`
      # because the latter's handler chain preventDefaults the click
      # and suppresses the new tab.
      create_link = ".radio a[href*='/locations/new?where=']" \
                    "[target='_blank']" \
                    "[rel='noopener noreferrer']" \
                    "[data-action='click->modal#hide']"
      assert_html(html, create_link,
                  text: :form_violations_modal_target_location_create.l)
    end

    def test_create_link_passes_suffix_as_where_param
      # Confirms the exact param-encoding of the suffix on the Create
      # link — the param-name regression that motivated #4304.
      obs = Observation.create!(
        user: @project.user,
        where: "Unique Place X42, Unique County X42, California, USA",
        when: Time.zone.today,
        name: Name.unknown
      )

      html = render(TargetLocationForm.new(
                      obs: obs, project: @project,
                      existing_locations: existing_for(obs)
                    ))

      encoded = "Unique+County+X42%2C+California%2C+USA"
      assert_html(html,
                  ".radio a[href='/locations/new?where=#{encoded}']" \
                  "[target='_blank']")
    end

    def test_does_not_use_deprecated_helpers_accessor
      # Regression guard for the phlex-rails `helpers` deprecation
      # (#4304). Render the form and confirm no warning is emitted.
      obs = Observation.create!(
        user: @project.user,
        where: "Suffix Test Place, Sample County, California, USA",
        when: Time.zone.today,
        name: Name.unknown
      )

      stderr_io = StringIO.new
      original_stderr = $stderr
      $stderr = stderr_io
      begin
        render(TargetLocationForm.new(
                 obs: obs, project: @project,
                 existing_locations: existing_for(obs)
               ))
      ensure
        $stderr = original_stderr
      end
      assert_no_match(/`helpers` method is deprecated/, stderr_io.string)
    end

    private

    def render_form
      render(TargetLocationForm.new(
               obs: @obs, project: @project,
               existing_locations: existing_for(@obs)
             ))
    end

    # Mirrors `Projects::ViolationsController#lookup_existing_target_suffixes` —
    # `TargetLocationForm` requires `existing_locations:` so the form
    # doesn't run a query in `view_template`.
    def existing_for(obs)
      suffixes = TargetLocationForm.suffixes_for(obs)
      Location.where(name: suffixes).index_by(&:name)
    end

    # Lightweight stand-in: TargetLocationForm.suffixes_for only reads
    # `obs.location_id`, `obs.location.name`, and `obs.where` — a Struct
    # works without needing a fully-built Observation fixture for each
    # `comma_suffixes` permutation.
    def mock_obs(where:)
      Struct.new(:location_id, :location, :where).new(nil, nil, where)
    end
  end
end
