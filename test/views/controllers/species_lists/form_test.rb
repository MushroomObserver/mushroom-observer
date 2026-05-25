# frozen_string_literal: true

require("test_helper")

# Tests for Views::Controllers::SpeciesLists::Form — the Phlex
# Superform that replaces app/views/controllers/species_lists/_form.html.erb
# plus the species_lists/form/_fields_for_project.erb sub-partial.
# Covers each field and the conditional rendering branches (clone_id
# present/absent, projects empty/populated, owner vs non-owner
# disable rules).
module Views::Controllers::SpeciesLists
  class FormTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
    end

    def test_create_flow_form_action_and_method
      html = render_form(species_list: SpeciesList.new)

      # New (non-persisted) SpeciesList → POST /species_lists.
      assert_html(html,
                  "form#species_list_form[action='/species_lists']" \
                  "[method='post']")
      # Superform: non-persisted → `_method=post` (no method override).
      assert_html(html,
                  "input[type='hidden'][name='_method'][value='post']")
    end

    def test_edit_flow_form_action_and_patch_method
      spl = species_lists(:first_species_list)
      html = render_form(species_list: spl)

      # Persisted SpeciesList → PATCH /species_lists/:id (via _method
      # hidden).
      assert_html(html,
                  "form#species_list_form" \
                  "[action='/species_lists/#{spl.id}']")
      assert_html(html,
                  "input[type='hidden'][name='_method'][value='patch']")
    end

    def test_clone_id_renders_when_set
      html = render_form(species_list: SpeciesList.new, clone_id: 42)

      # `clone_id` is top-level, NOT under the species_list
      # namespace — the controller reads `params[:clone_id]`.
      assert_html(html,
                  "input[type='hidden'][name='clone_id'][value='42']")
    end

    def test_clone_id_omitted_when_nil
      html = render_form(species_list: SpeciesList.new, clone_id: nil)
      assert_no_html(html, "input[name='clone_id']")
    end

    def test_approved_where_hidden_field_namespaced_under_species_list
      # `approved_where` is the dubious-confirmation flag. Pre-Phlex
      # it lived as a top-level URL query param on the form action;
      # post-Phlex it's a hidden field under the species_list
      # namespace.
      spl = species_lists(:first_species_list)
      html = render_form(species_list: spl)

      assert_html(html,
                  "input[type='hidden']" \
                  "[name='species_list[approved_where]']" \
                  "[value='#{spl.place_name}']")
    end

    def test_renders_title_notes_when_and_place_name_fields
      spl = species_lists(:first_species_list)
      html = render_form(species_list: spl)

      # Title text field (model attr — namespaced).
      assert_html(html,
                  "input[type='text'][name='species_list[title]']" \
                  "[value='#{spl.title}']")
      # Notes textarea (model attr).
      assert_html(html, "textarea[name='species_list[notes]']")
      # When: composite-date inputs (Rails' (1i)/(2i)/(3i) suffixes).
      assert_html(html, "[name='species_list[when(1i)]']")
      assert_html(html, "[name='species_list[when(2i)]']")
      assert_html(html, "[name='species_list[when(3i)]']")
      # place_name autocompleter input.
      assert_html(html, "[name='species_list[place_name]']")
    end

    def test_renders_submit_buttons_top_and_bottom
      html = render_form(species_list: SpeciesList.new, button: :CREATE)

      # `submit(button.l, center: true)` is called twice — one above
      # the fields and one below. Locks in the count so a future
      # refactor doesn't silently drop one.
      assert_html(html, "input[type='submit'][value='Create']",
                  count: 2)
    end

    def test_renders_project_checkboxes_when_projects_provided
      proj1 = projects(:eol_project)
      proj2 = projects(:bolete_project)
      spl = SpeciesList.new
      spl.project_ids = [proj1.id]
      html = render_form(species_list: spl, projects: [proj1, proj2])

      # Each project gets `name="species_list[project_ids][]"` (array
      # shape) with `value="<id>"`. Checkedness follows
      # `model.project_ids`; unchecked rows must NOT render the
      # `checked` attribute.
      assert_html(html,
                  "input[type='checkbox']" \
                  "[name='species_list[project_ids][]']" \
                  "[value='#{proj1.id}'][checked]",
                  count: 1)
      assert_html(html,
                  "input[type='checkbox']" \
                  "[name='species_list[project_ids][]']" \
                  "[value='#{proj2.id}']",
                  count: 1)
      assert_no_html(
        html,
        "input[type='checkbox']" \
        "[name='species_list[project_ids][]']" \
        "[value='#{proj2.id}'][checked]"
      )
      # One sentinel hidden input (value="") ensures the key is
      # always present in params even when every checkbox is
      # unchecked — Rack drops empty arrays otherwise. No per-project
      # hidden sidecars (disabled checkboxes also don't submit;
      # non-member projects the SL belongs to are preserved by the
      # controller's iterator over @user.projects_member).
      assert_html(
        html,
        "input[type='hidden']" \
        "[name='species_list[project_ids][]'][value='']",
        count: 1
      )
    end

    def test_project_section_omitted_when_no_projects
      html = render_form(species_list: SpeciesList.new, projects: [])

      # No "Projects:" label, no project checkboxes, no help-note.
      assert_no_html(html, "input[name='species_list[project_ids][]']")
    end

    def test_project_checkbox_disabled_for_non_owner_non_member
      # rolf_list is owned by rolf; dick is the @user (non-owner).
      # eol_project members: [rolf, mary, katrina] — dick is NOT a
      # member. bolete_project members: [mary, dick] — dick IS a
      # member. So dick should NOT be able to toggle eol_project
      # (disabled) but CAN toggle bolete_project (enabled).
      rolf_list = species_lists(:first_species_list)
      eol_proj = projects(:eol_project)
      bolete_proj = projects(:bolete_project)
      html = render_form(
        species_list: rolf_list,
        user: users(:dick),
        projects: [eol_proj, bolete_proj]
      )

      assert_html(
        html,
        "input[type='checkbox']" \
        "[name='species_list[project_ids][]']" \
        "[value='#{eol_proj.id}'][disabled]"
      )
      bolete_id = bolete_proj.id
      assert_no_html(
        html,
        "input[type='checkbox']" \
        "[name='species_list[project_ids][]']" \
        "[value='#{bolete_id}'][disabled]"
      )
    end

    def test_owner_can_modify_all_project_checkboxes
      # When the @user IS the species_list owner, all checkboxes
      # should be enabled regardless of project membership.
      rolf_list = species_lists(:first_species_list)
      not_a_member_proj = projects(:bolete_project)
      html = render_form(
        species_list: rolf_list,
        user: users(:rolf),
        projects: [not_a_member_proj]
      )

      assert_no_html(
        html,
        "input[type='checkbox']" \
        "[name='species_list[project_ids][]']" \
        "[value='#{not_a_member_proj.id}'][disabled]"
      )
    end

    # On a failure-reload the controller passes the user's
    # just-submitted `project_ids` as `submitted_project_ids:` (so
    # we don't have to write them to the DB just to render them
    # back — Rails' has_many-through `*_ids=` setter is instant on
    # a persisted record). The form uses that array for checkedness
    # in preference to `model.project_ids`.
    def test_submitted_project_ids_overrides_model_for_checkedness
      proj1 = projects(:eol_project)
      proj2 = projects(:bolete_project)
      spl = species_lists(:first_species_list)
      # Force model state: spl belongs to proj1 only.
      spl.projects = [proj1]
      # User just submitted proj2 only (different from model's state).
      html = render_form(
        species_list: spl,
        projects: [proj1, proj2],
        submitted_project_ids: [proj2.id.to_s]
      )

      # proj2 should be checked (matches submitted, not model).
      assert_html(
        html,
        "input[type='checkbox']" \
        "[name='species_list[project_ids][]']" \
        "[value='#{proj2.id}'][checked]",
        count: 1
      )
      # proj1 should NOT be checked (matches submitted, not model).
      assert_no_html(
        html,
        "input[type='checkbox']" \
        "[name='species_list[project_ids][]']" \
        "[value='#{proj1.id}'][checked]"
      )
    end

    def test_renders_form_location_feedback_when_dubious_reasons_present
      # FormLocationFeedback (still in components/, used by 3
      # controllers) shows the dubious-place warning + an "approve
      # anyway" button. The form just delegates; it should pass
      # `dubious_where_reasons` through.
      html = render_form(
        species_list: SpeciesList.new,
        dubious_where_reasons: ["dubious_county_unrecognized"]
      )
      assert_html(html, "#dubious_location_messages")
    end

    private

    def render_form(species_list:, **)
      defaults = {
        projects: [], dubious_where_reasons: [],
        user: @user, button: :CREATE, clone_id: nil
      }
      render(Form.new(species_list, **defaults, **))
    end
  end
end
