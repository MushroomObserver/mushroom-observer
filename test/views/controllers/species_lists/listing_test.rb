# frozen_string_literal: true

require("test_helper")

module Views::Controllers::SpeciesLists
  # Tests for one species_list "listing" row used by the index and the
  # observation-attach edit page.
  class ListingTest < ComponentTestCase
    def setup
      super
      @species_list = species_lists(:unknown_species_list)
      @observation = observations(:minimal_unknown_obs)
    end

    # Listing renders contents only — the `list-group-item` wrapper
    # comes from `Components::ListGroup#item` in the Index view, so
    # standalone-render output should NOT have it.
    def test_renders_basic_row
      html = render_listing

      assert_no_html(html, ".list-group-item")
      assert_html(html, ".list_info")
      # badge-md badge with species_list id
      assert_html(html, ".badge-md")
      # text_name link → species_list show path
      assert_html(html, ".list_what.h4")
      assert_html(html, ".list_when")
    end

    # No `remove` / `add` flag → no `.list_manage` slot at all.
    def test_does_not_render_manage_section_by_default
      html = render_listing

      assert_no_html(html, ".list_manage")
      assert_no_html(html, "form")
    end

    # `remove: true` → put-button with `commit=remove`, modern Turbo
    # confirm (data-turbo-confirm, not the legacy data-confirm).
    def test_renders_remove_button_when_remove_true
      html = render_listing(observation: @observation, remove: true)

      assert_html(html, ".list_manage form")
      remove_path = routes.observation_species_list_path(
        id: @observation.id,
        species_list_id: @species_list.id,
        commit: "remove"
      )
      assert_html(html, "form[action='#{remove_path}']")
      assert_html(html, "input[name='_method'][value='put']")
      assert_html(html, "[data-turbo-confirm]")
      assert_html(html, "form button", text: :remove.ti)
    end

    # `add: true` → put-button with `commit=add`; no confirm.
    def test_renders_add_button_when_add_true
      html = render_listing(observation: @observation, add: true)

      assert_html(html, ".list_manage form")
      add_path = routes.observation_species_list_path(
        id: @observation.id,
        species_list_id: @species_list.id,
        commit: "add"
      )
      assert_html(html, "form[action='#{add_path}']")
      assert_html(html, "input[name='_method'][value='put']")
      assert_no_html(html, "[data-turbo-confirm]")
      assert_html(html, "form button", text: :add.ti)
    end

    # `place` rescues StandardError from `place_name.t` and falls back
    # to `:unknown.ti`. Stub `place_name` to raise so the rescue fires.
    def test_place_falls_back_to_unknown_when_place_name_raises
      @species_list.define_singleton_method(:place_name) do
        raise(StandardError.new("bad place"))
      end
      html = render_listing

      assert_html(html, "span", text: :unknown.ti.as_displayed)
    end

    # `remove` wins when both flags set — defensive guard.
    def test_remove_wins_when_both_remove_and_add_set
      html = render_listing(observation: @observation,
                            remove: true, add: true)

      assert_html(html, "form button", text: :remove.ti)
      # `assert_no_html` doesn't take `text:`, so verify "only one
      # form rendered" instead — guarantees both buttons can't be
      # present simultaneously.
      assert_html(html, "form", count: 1)
    end

    private

    def render_listing(species_list: @species_list,
                       observation: nil, remove: false, add: false,
                       project: nil)
      render(Views::Controllers::SpeciesLists::Listing.new(
               species_list: species_list,
               observation: observation,
               remove: remove,
               add: add,
               project: project
             ))
    end
  end
end
