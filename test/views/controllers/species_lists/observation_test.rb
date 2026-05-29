# frozen_string_literal: true

require("test_helper")

module Views::Controllers::SpeciesLists
  # Tests for one observation row on the species_list show page.
  # Covers the two layout modes (image / no-image), the conditional
  # remove button, and the link wiring.
  class ObservationTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
      @species_list = species_lists(:unknown_species_list)
      @observation = observations(:minimal_unknown_obs)
    end

    def test_renders_list_group_item_with_observation_link
      html = render_row

      assert_html(html, ".list-group-item .row")
      obs_path = view_context.observation_path(id: @observation.id)
      assert_html(html, "a[href='#{obs_path}']")
      # Always renders the who+when line.
      assert_html(html,
                  "a[href='#{view_context.user_path(@observation.user.id)}']")
    end

    # When `image: true` the row is two-column (image + details);
    # when false it's a single full-width column.
    def test_renders_two_column_layout_when_image
      html = render_row(image: true)

      # Image column class + details column class
      assert_html(html, ".col-sm-4.col-md-3")
      assert_html(html, ".col-sm-8.col-md-9")
      assert_no_html(html, ".col-xs-12")
    end

    def test_renders_single_column_layout_without_image
      html = render_row(image: false)

      assert_html(html, ".col-xs-12")
      assert_no_html(html, ".col-sm-4.col-md-3")
      assert_no_html(html, ".col-sm-8.col-md-9")
    end

    # `remove: true` (set by the show page when the viewer can edit)
    # renders the inline put-button.
    def test_renders_remove_button_when_remove_true
      html = render_row(remove: true)

      assert_html(html, ".manage_observation")
      remove_path = view_context.observation_species_list_path(
        id: @observation.id,
        species_list_id: @species_list.id,
        commit: "remove"
      )
      assert_html(html, "form[action='#{remove_path}']")
      assert_html(html, "input[name='_method'][value='put']")
      assert_html(html, "[data-turbo-confirm]")
    end

    def test_does_not_render_remove_button_when_remove_false
      html = render_row(remove: false)

      assert_no_html(html, ".manage_observation")
      assert_no_html(html, "form")
    end

    private

    def render_row(image: false, remove: false)
      render(Views::Controllers::SpeciesLists::Observation.new(
               observation: @observation,
               user: @user,
               species_list: @species_list,
               image: image,
               remove: remove
             ))
    end
  end
end
