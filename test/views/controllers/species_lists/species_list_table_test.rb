# frozen_string_literal: true

require("test_helper")

module Views::Controllers::SpeciesLists
  class SpeciesListTableTest < ComponentTestCase
    def setup
      super
      @species_list = species_lists(:unknown_species_list)
      @observation = observations(:minimal_unknown_obs)
    end

    def test_renders_one_row_per_species_list
      other = species_lists(:first_species_list)
      html = render_table([@species_list, other])

      assert_html(html, "tbody tr", count: 2)
      assert_html(html, ".badge-id", count: 2)
      assert_html(html, ".list_what")
      assert_html(html, "div", text: @species_list.when.to_s)
    end

    def test_does_not_render_manage_section_by_default
      html = render_table([@species_list])

      assert_no_html(html, "form")
    end

    def test_renders_zero_count_badge_when_list_missing_from_hash
      html = render_table([@species_list])

      assert_html(html, ".count-badge", text: "0")
    end

    def test_renders_count_badge_from_observation_counts
      html = render_table(
        [@species_list],
        observation_counts: { @species_list.id => 5 }
      )

      assert_html(html, ".count-badge", text: "5")
    end

    def test_renders_remove_button_when_remove_true
      html = render_table([@species_list], observation: @observation,
                                           remove: true)

      remove_path = routes.observation_species_list_path(
        id: @observation.id,
        species_list_id: @species_list.id
      )
      assert_html(html, "form[action='#{remove_path}']")
      assert_html(html, "input[name='_method'][value='delete']")
      assert_html(html, "[data-turbo-confirm]")
      assert_html(html, "form button", text: :remove.ti)
      assert_no_html(html, ".count-badge")
    end

    def test_renders_add_button_when_add_true
      html = render_table([@species_list], observation: @observation,
                                           add: true)

      add_path = routes.observation_species_list_path(
        id: @observation.id,
        species_list_id: @species_list.id
      )
      assert_html(html, "form[action='#{add_path}']")
      assert_html(html, "input[name='_method'][value='put']")
      assert_no_html(html, "[data-turbo-confirm]")
      assert_html(html, "form button", text: :add.ti)
    end

    # `remove` wins when both flags set — defensive guard.
    def test_remove_wins_when_both_remove_and_add_set
      html = render_table([@species_list], observation: @observation,
                                           remove: true, add: true)

      assert_html(html, "form button", text: :remove.ti)
      assert_html(html, "form", count: 1)
    end

    # `manageable_ids` gates the button -- a row whose id isn't
    # listed gets a blank action cell, not a button.
    def test_no_button_when_not_manageable
      html = render_table([@species_list], observation: @observation,
                                           remove: true, manageable_ids: [])

      assert_no_html(html, "form")
    end

    def test_button_when_manageable
      html = render_table([@species_list], observation: @observation,
                                           remove: true,
                                           manageable_ids: [@species_list.id])

      assert_html(html, "form")
    end

    def test_place_falls_back_to_unknown_when_place_name_raises
      @species_list.define_singleton_method(:place_name) do |_user|
        raise(StandardError.new("bad place"))
      end
      html = render_table([@species_list])

      assert_html(html, "span", text: :unknown.ti.as_displayed)
    end

    private

    def routes
      Rails.application.routes.url_helpers
    end

    def render_table(objects, **)
      render(SpeciesListTable.new(objects, **))
    end
  end
end
