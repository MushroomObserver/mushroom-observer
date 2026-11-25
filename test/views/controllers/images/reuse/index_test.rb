# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Images::Reuse
  class IndexTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
      @obs = observations(:minimal_unknown_obs)
    end

    def test_renders_form_and_image_matrix
      image = images(:in_situ_image)
      html = render_index(objects: [image])

      assert_html(html, "input[name='image_reuse[img_id]']")
      assert_html(html, "#box_#{image.id}")
    end

    def test_renders_all_users_toggle_with_both_options
      html = render_index

      assert_html(html, "select[name='all_users']")
      assert_html(html, "option[value='0'][selected]",
                  text: :image_reuse_just_yours.t.as_displayed)
      assert_html(html, "option[value='1']",
                  text: :image_reuse_all_users.t.as_displayed)
    end

    def test_all_users_true_selects_the_all_images_option
      html = render_index(all_users: true)

      assert_html(html, "option[value='1'][selected]")
      assert_no_html(html, "option[value='0'][selected]")
    end

    def test_toggle_autosubmits_on_change
      html = render_index

      url = routes.images_reuse_path(target_type: "Observation",
                                     target_id: @obs.id)
      assert_html(html,
                  "form[data-controller='autosubmit'][action='#{url}']")
      assert_html(html, "select[data-action='change->autosubmit#submit']")
    end

    private

    def render_index(objects: [], all_users: false)
      render(Index.new(
               target: @obs,
               user: @user,
               objects: objects,
               pagination_data: PaginationData.new,
               all_users: all_users
             ))
    end
  end
end
