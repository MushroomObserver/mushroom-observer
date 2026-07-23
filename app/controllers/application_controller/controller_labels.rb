# frozen_string_literal: true

# ==== Controller labels
# Naming / labeling helpers driven off the controller's class name —
# all read-only, request-scoped, and exposed to views.
#
# `controller_model_name` is the singular CamelCase model name
# (e.g. `Observations` → `Observation`). Default `controller_name.classify`,
# but several controllers override it (`ProjectsController`, the
# `*::DescriptionsController` subclasses, etc.) when the model name
# doesn't follow the default rule.
#
# `rubric` is a translation string label for "what we're dealing with
# on this page, generally" — usually `controller_name` like
# `OBSERVATIONS` or `ACCOUNT`. For nested controllers like
# `Locations::Descriptions::DefaultsController` it returns the outer
# module name (`LOCATIONS`) instead. Read by `Views::Layouts::TopNav`
# and the page-chrome breadcrumb / title helpers.
#
# `parent_controller_module` is the CamelCase parent module name, or
# nil for top-level controllers. Used directly by TopNav's
# `nav_linkable_parent_controller` and by `rubric` itself.
#
# Lives in its own module so `ComponentTestCase` can include it on
# the test controller without pulling in the rest of
# `ApplicationController` — the Phlex layout / TopNav rendering path
# walks through all three of these in every component test.
module ApplicationController::ControllerLabels
  def self.included(base)
    base.helper_method(:rubric, :parent_controller_module,
                       :controller_model_name)
  end

  # Singular CamelCase model name. `ObservationsController` → `Observation`.
  # Several controllers override.
  def controller_model_name
    controller_name.classify
  end

  # Returns a translation string.
  def rubric
    if (parent = parent_controller_module)
      return parent.underscore.to_sym.ti
    end

    controller_name.to_sym.ti
  end

  # `gotcha` — `Object` is the module_parent of a top-level
  # controller, so we have to filter it out. Also filter
  # `ActionView::` / `ActionDispatch::` — those are the
  # `module_parent` values for `ActionView::TestCase::TestController`
  # and `ActionDispatch::IntegrationTest::TestController`, used by
  # the test infrastructure. Production controllers never have
  # those as a parent.
  def parent_controller_module
    parent_module = self.class.module_parent
    return if parent_module.blank? || parent_module == Object
    return if parent_module.name.start_with?("ActionView::",
                                             "ActionDispatch::")

    if (grandma_module = parent_module.to_s.rpartition("::").first).present?
      return grandma_module
    end

    parent_module.to_s
  end
end
