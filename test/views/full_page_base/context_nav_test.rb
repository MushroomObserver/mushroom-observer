# frozen_string_literal: true

require("test_helper")

# Tests for `Views::FullPageBase::ContextNav`:
#
#   - `add_context_nav(nil)` and `add_context_nav([])` no-op.
#   - `add_context_nav([tuples])`, `add_context_nav(Tab::Collection)`,
#     `add_context_nav(Tab::Base)` all populate both
#     `content_for(:context_nav)` (top-bar dropdown) and
#     `(:context_nav_mobile)` (offcanvas sidebar).
#
# End-to-end HTML output for each link-tuple shape is exercised by
# the focused tests on `Views::Layouts::TopNav::ContextNav` /
# `Views::Layouts::Sidebar::ContextNav` and (transitively)
# `Views::Layouts::ContextNav::LinkRendering` /
# `Components::Dropdown`.
class Views::FullPageBase::ContextNavTest < ComponentTestCase
  # ----- guard clauses (no-op when nothing to render) ---------------

  def test_nil_links_does_not_populate_slots
    top, mobile = render_and_capture_slots do
      add_context_nav(nil)
    end

    assert_nil(top)
    assert_nil(mobile)
  end

  def test_empty_array_does_not_populate_slots
    top, mobile = render_and_capture_slots do
      add_context_nav([])
    end

    assert_nil(top)
    assert_nil(mobile)
  end

  def test_array_of_only_nil_tuples_does_not_populate_slots
    # Tab POROs can yield nil entries (filtered branches in
    # `Tab::Collection#tabs`); after compact the list is empty.
    top, mobile = render_and_capture_slots do
      add_context_nav([nil, nil])
    end

    assert_nil(top)
    assert_nil(mobile)
  end

  # ----- legacy tuple-array input ----------------------------------

  def test_array_of_tuples_populates_both_slots
    links = [["Foo", "/foo", { class: "foo_link" }]]

    top, mobile = render_and_capture_slots do
      add_context_nav(links)
    end

    assert_not_nil(top)
    assert_not_nil(mobile)
    assert_includes(top, "foo_link")
    assert_includes(mobile, "foo_link")
  end

  # ----- Tab::Base / Tab::Collection input -------------------------

  def test_tab_base_input_wraps_into_single_element_list
    tab = ::Tab::Project::Summary.new(project: projects(:bolete_project))

    top, mobile = render_and_capture_slots do
      add_context_nav(tab)
    end

    assert_not_nil(top)
    assert_not_nil(mobile)
    assert_includes(top, tab.title)
    assert_includes(mobile, tab.title)
  end

  def test_tab_collection_input_renders_each_tab
    user = users(:mary)
    collection = ::Tab::Project::Banner.new(
      project: projects(:bolete_project), user: user
    )
    controller.instance_variable_set(:@user, user)

    top, mobile = render_and_capture_slots do
      add_context_nav(collection)
    end

    assert_not_nil(top)
    assert_not_nil(mobile)
    # The summary tab is always present in the project banner;
    # use its title as a "the collection rendered" smoke marker.
    assert_includes(top, ::Tab::Project::Summary.new(
      project: projects(:bolete_project)
    ).title)
  end

  private

  # Render a one-off `Views::FullPageBase` subclass that calls
  # `add_context_nav(...)` from its `view_template`, then reads the
  # `:context_nav` + `:context_nav_mobile` slots from inside the
  # same render context. Skips `around_template` so the test
  # doesn't pull in the full Application layout.
  def render_and_capture_slots(&setup_block)
    captured = []
    page_class = Class.new(Views::FullPageBase) do
      define_method(:view_template) do
        instance_eval(&setup_block)
        captured << content_for(:context_nav)
        captured << content_for(:context_nav_mobile)
      end
      def around_template
        yield
      end
    end
    render(page_class.new)
    captured
  end
end
