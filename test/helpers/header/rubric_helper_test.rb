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

    def test_nav_create_returns_blank_for_non_createable_controller
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

      # Visible text is the short word "Add". Screen-reader users
      # and hover-tooltip viewers get the full "New Observation" via
      # aria-label and title.
      assert_equal(:ADD.l, a.text.strip)
      assert_equal("New Observation", a["aria-label"])
      assert_equal("New Observation", a["title"])
    end

    def test_nav_create_drops_the_plus_glyph
      # Pre-#3930 the button rendered a `glyphicon-plus` inside a
      # `link-icon` span. The new button is text-only.
      doc = Nokogiri::HTML(nav_create(@user, stub_controller("observations")))

      assert_empty(doc.css(".glyphicon-plus"))
      assert_empty(doc.css(".link-icon"))
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
