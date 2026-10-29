# frozen_string_literal: true

require("test_helper")

# Contract tests for `Views::Layouts::Header::ObjectTitle` — the
# title piece rendered into `content_for(:title)` for show and edit
# pages. The id badge is a separate slot, owned by `Header::PageTitle`
# (see page_title_test.rb) — not rendered here.
module Views::Layouts
  class Header::ObjectTitleTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
    end

    def test_show_mode_observation_delegates_to_consensus_name_link
      obs = observations(:minimal_unknown_obs)

      html = render_title(object: obs)

      # Full behavior of the consensus-name chain (deprecated names,
      # owner-preference flags, ...) is tested at
      # consensus_name_link_test.rb — this only confirms ObjectTitle
      # delegates to it for an Observation.
      assert_html(html, "a[href='#{routes.name_path(id: obs.name.id)}']")
    end

    def test_show_mode_non_observation_renders_title_for_page_title
      herbarium = herbaria(:nybg_herbarium)

      html = render_title(object: herbarium)

      assert_includes(html, Title.for(herbarium).page_title(@user))
    end

    def test_title_prop_overrides_computed_title
      obs = observations(:minimal_unknown_obs)

      html = render_title(object: obs, title: "Custom Title Override")

      assert_includes(html, "Custom Title Override")
      assert_no_html(html, "a[href='#{routes.name_path(id: obs.name.id)}']")
    end

    def test_edit_mode_prepends_edit_label
      obs = observations(:minimal_unknown_obs)

      html = render_title(object: obs, mode: :edit)

      assert_includes(html, :edit_object.t(type: obs.type_tag).to_s)
      # Still renders the title piece after the label.
      assert_html(html, "a[href='#{routes.name_path(id: obs.name.id)}']")
    end

    def test_owner_naming_renders_as_second_line_when_present
      obs = observations(:minimal_unknown_obs)

      html = render_title(object: obs,
                          owner_naming: "<em>Best guess</em>".html_safe)

      assert_html(html, "#owner_naming em", text: "Best guess")
    end

    def test_owner_naming_absent_when_not_given
      obs = observations(:minimal_unknown_obs)

      html = render_title(object: obs)

      assert_no_html(html, "#owner_naming")
    end

    private

    def render_title(object:, user: @user, mode: :show, title: nil,
                     owner_naming: nil)
      render(Header::ObjectTitle.new(
               object: object, user: user, mode: mode,
               title: title, owner_naming: owner_naming
             ))
    end
  end
end
