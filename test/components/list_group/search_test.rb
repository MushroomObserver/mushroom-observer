# frozen_string_literal: true

require("test_helper")

class ListSearchTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    User.current = @user
  end

  # ---- Project caller ----

  def test_renders_for_project_panel_form_and_hidden_fields
    project = projects(:bolete_project)
    html = render_for(project, project: project)

    # Panel wrap (matches `panel_id: "list_search"`).
    assert_html(html, "div#list_search.panel")
    # Form posts to AddDispatchController with explicit POST verb
    # (no PATCH/PUT here — controller uses GET-of-redirect).
    assert_html(html, "form#list_search_form[action='/add_dispatch']" \
                      "[method='post']")
    # The three hidden fields the controller reads as flat params.
    assert_html(html, "input[type='hidden'][name='object_id']" \
                      "[value='#{project.id}']")
    assert_html(html, "input[type='hidden'][name='object_type']" \
                      "[value='Project']")
    assert_html(html, "input[type='hidden'][name='project']" \
                      "[value='#{project.id}']")
  end

  # ---- Species-list caller ----

  def test_renders_for_species_list_with_optional_project
    spl = species_lists(:first_species_list)
    project = projects(:bolete_project)
    html = render_for(spl, project: project)

    assert_html(html, "input[type='hidden'][name='object_id']" \
                      "[value='#{spl.id}']")
    assert_html(html, "input[type='hidden'][name='object_type']" \
                      "[value='SpeciesList']")
    # Optional project still threads through to the hidden field.
    assert_html(html, "input[type='hidden'][name='project']" \
                      "[value='#{project.id}']")
  end

  def test_renders_for_species_list_without_project
    spl = species_lists(:first_species_list)
    html = render_for(spl, project: nil)

    # `project: nil` renders the hidden field with empty value.
    assert_html(html, "input[type='hidden'][name='project'][value='']")
  end

  # ---- Search-status Stimulus wiring ----

  def test_search_status_value_attrs_are_json_encoded
    project = projects(:bolete_project)
    html = render_for(project, project: project)

    # Both Stimulus value attrs are JSON, not Ruby `to_s` (Phlex
    # doesn't auto-encode Hash / Relation values into `data-*` the way
    # Rails does, so the component calls `.to_json` explicitly).
    assert_html(html,
                "div.search-status[data-controller='search-status']" \
                "[data-search-status-messages-value*='Enter text to']" \
                "[data-search-status-matches-value^='[']")
  end

  def test_initial_status_text_keyed_to_autocompleter_field_name
    project = projects(:bolete_project)
    html = render_for(project, project: project)

    # The initial visible message uses `type: :name` (matching the ERB
    # partial's literal default). The Stimulus controller swaps it
    # later with one of the per-`type_tag` strings from `messages_value`.
    assert_html(html, "span.status-text[data-search-status-target='message']",
                text: :search_status_all_names.l(type: :name))
  end

  # ---- Search inputs ----

  def test_field_slip_and_name_inputs_use_flat_param_names
    project = projects(:bolete_project)
    html = render_for(project, project: project)

    assert_html(html, "input[type='text'][name='field_slip']")
    assert_html(html, "input[type='text'][name='name']")
    assert_html(html, "input[type='submit'][value='Add']")
  end

  private

  def render_for(object, project: nil)
    object_names = object.observations.joins(:name).
                   select(Name[:text_name], Name[:id]).distinct.
                   order(Name[:text_name])
    render(Components::ListGroup::Search.new(
             object: object, object_names: object_names, project: project
           ))
  end
end
