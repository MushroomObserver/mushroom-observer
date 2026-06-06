# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Comments
  class ShowTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
      controller.instance_variable_set(:@user, @user)
    end

    def test_observation_target_renders_four_paragraphs
      # `register_target_names` walks the namings (`when "Observation"`
      # branch); the body renders four `<p>` lines: created_at,
      # author, summary, comment.
      comment = comments(:minimal_unknown_obs_comment_1)

      html = render(Show.new(comment: comment, target: comment.target,
                             user: @user))

      assert_html(html, "a.user_link_#{comment.user.id}")
      assert_includes(html, comment.summary)
      # `comment_show_comment` localized label appears in the
      # textile-rendered body line.
      assert_includes(html, :comment_show_comment.l)
    end

    def test_name_target_registers_synonyms_and_target
      # Forces the `when "Name"` branch in `register_target_names`
      # so the synonym + target registrations run. The header
      # paragraphs render even when the body Textile is empty.
      target = names(:agaricus_campestris)
      comment = ::Comment.create!(target: target, user: @user,
                                  summary: "On the Name", comment: "")

      html = render(Show.new(comment: comment, target: target,
                             user: @user))

      assert_includes(html, "On the Name")
      assert_html(html, "a.user_link_#{@user.id}")
    end
  end
end
