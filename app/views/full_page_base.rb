# frozen_string_literal: true

# Base class for top-level action views — every Phlex class a
# controller renders via `render(Views::Controllers::Foo::Bar.new(…))`.
# Layout sub-pieces (Sidebar, Header, TopNav, etc.) stay on `Views::Base`
# and never fire the wrap.
#
# `around_template` wraps the action's content in the application or
# printable layout. The action's `view_template` runs first (via
# `capture`), populating `content_for` slots as a side effect — that
# matches Rails' ERB layout/template ordering, where the layout reads
# `content_for(:container_class)` etc. after the template has set them.
#
# Per-concern modules under `Views::FullPageBase::*` host the
# `add_*` setters that action views call to populate those slots
# (page-title, etc.). Each module is `include`d below.
class Views::FullPageBase < Views::Base
  include LayoutClasses
  include Title
  include Icons
  include ProjectBanner
  include IndexNav
  include ShowPager
  include ContextNav

  def around_template
    action_html = capture { super }
    populate_default_layout_class_slots
    render(layout_class.new(**layout_props)) { trusted_html(action_html) }
  end

  private

  # After the action's `view_template` has set whichever
  # `content_for(:container_class)` / `(:left_columns)` /
  # `(:content_padding)` slots it cares about, fill the rest with
  # defaults so the Application layout can just `content_for(slot)`
  # without nil-handling.
  def populate_default_layout_class_slots
    default_container_class
    default_column_classes
    default_content_padding
  end

  def layout_class
    case controller.session[:layout].to_s
    when "printable" then Views::Layouts::Printable
    else Views::Layouts::Application
    end
  end

  # `@canonical_url` (set by show actions, ~13 controllers) and
  # `@any_content_filters_applied` (set by `set_index_view_ivars` on
  # every index plus the 3 maps controllers) are the controller-set
  # chrome ivars the Application layout needs. The around_template is
  # the boundary that translates controller request-state into Phlex
  # layout props — the layout itself stays prop-clean.
  def layout_props
    return {} if layout_class == Views::Layouts::Printable

    { canonical_url: ctrl_ivar(:canonical_url),
      any_content_filters_applied: ctrl_ivar(:any_content_filters_applied) }
  end

  def ctrl_ivar(name)
    controller.instance_variable_get(:"@#{name}")
  end
end
