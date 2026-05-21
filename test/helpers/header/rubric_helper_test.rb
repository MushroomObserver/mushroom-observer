# frozen_string_literal: true

require("test_helper")

module Header
  # Tests for `Header::RubricHelper#nav_create` — the green "Add" button
  # rendered in the top-nav rubric on index pages for models in
  # NAV_CREATABLES. See #3930 for the redesign that replaced the
  # outlined `[+]` icon button with this `[Add]` styling.
  class RubricHelperTest < ActionView::TestCase
    include LinkHelper

    def setup
      @user = users(:rolf)
    end

    def test_nav_create_returns_blank_without_user
      html = nav_create(nil, stub_controller("observations"))

      assert_equal("", html)
    end

    def test_nav_create_returns_blank_when_controller_lacks_new_action
      ctrl = stub_controller("observations")
      ctrl.define_singleton_method(:methods) do |*|
        super().reject { |m| m == :new }
      end

      html = nav_create(@user, ctrl)

      assert_equal("", html)
    end

    def test_nav_create_returns_blank_for_non_creatable_controller
      # `comments` is in NAV_INDEXABLES but not NAV_CREATABLES.
      html = nav_create(@user, stub_controller("comments"))

      assert_equal("", html)
    end

    def test_nav_create_renders_solid_green_add_button
      html = nav_create(@user, stub_controller("observations"))
      a = anchor(html)

      assert_equal("/observations/new", a["href"])
      classes = a["class"].split
      # Solid green styling replaces the previous `btn-outline-default`.
      assert_includes(classes, "btn")
      assert_includes(classes, "btn-success")
      assert_includes(classes, "btn-sm")
      assert_includes(classes, "top_nav_button")
    end

    def test_nav_create_uses_per_controller_label_for_aria_and_title
      html = nav_create(@user, stub_controller("observations"))
      a = anchor(html)

      # Screen-reader users and hover-tooltip viewers get the full
      # "New Observation" via aria-label and title. (Visible content
      # is just `+` on phones and `+ Add` on tablet+; either way
      # aria-label overrides the link's accessible name.)
      assert_equal("New Observation", a["aria-label"])
      assert_equal("New Observation", a["title"])
    end

    def test_nav_create_renders_plus_glyph
      # The `+` icon is always present; the "Add" word only appears
      # at `sm` and above.
      doc = Nokogiri::HTML(nav_create(@user, stub_controller("observations")))
      glyph = doc.at_css("a .glyphicon-plus.link-icon")

      assert_not_nil(glyph, "Expected `+` glyph inside the button")
    end

    def test_nav_create_hides_add_text_below_sm_breakpoint
      # The "Add" word lives in a `d-none d-sm-inline` span so it's
      # hidden below `$screen-sm-min` (768px) and visible at `sm`+.
      # Matches iNat's mobile pattern of collapsing the create CTA
      # to its icon — see the discussion on PR #4302.
      doc = Nokogiri::HTML(nav_create(@user, stub_controller("observations")))
      span = doc.at_css("a span.d-none.d-sm-inline")

      assert_not_nil(span,
                     "Expected `Add` text in a `d-none d-sm-inline` span")
      assert_equal(:ADD.l, span.text.strip)
    end

    private

    # Stub controller responding to the four methods `nav_create` reads.
    # Real controllers also have these (they're standard Rails plus
    # MO's `controller_model_name`), but instantiating each real
    # controller here would pull in a lot of unrelated setup.
    def stub_controller(name)
      model_name = name.classify
      Struct.new(:controller_name, :controller_path,
                 :controller_model_name) do
        def methods(*)
          super() + [:new]
        end
      end.new(name, name, model_name)
    end

    def anchor(html)
      Nokogiri::HTML(html).at_css("a")
    end
  end
end
