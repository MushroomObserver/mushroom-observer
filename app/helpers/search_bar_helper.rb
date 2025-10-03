# frozen_string_literal: true

module SearchBarHelper
  SEARCH_BAR_TOGGLE_CLASSES = %w[btn btn-link navbar-link px-2].freeze

  def search_help_toggle(help_controller: false)
    classes = SEARCH_BAR_TOGGLE_CLASSES.dup
    classes << "d-none" unless help_controller
    tag.button(
      link_icon(:info, title: :search_bar_help.t),
      class: class_names(classes),
      type: :button,
      data: { toggle: "collapse", search_type_target: "helpToggle",
              target: "#search_bar_help" },
      aria: { expanded: "false", controls: "search_bar_help" }
    )
  end

  def search_form_toggle(form_controller: false)
    classes = SEARCH_BAR_TOGGLE_CLASSES.dup
    classes << "d-none" unless form_controller
    tag.button(
      link_icon(:plus, title: :search_bar_more_options.l),
      class: class_names(classes),
      type: :button,
      data: { toggle: "collapse", search_type_target: "formToggle",
              target: "#search_nav_form" },
      aria: { expanded: "false", controls: "search_nav_form" }
    )
  end

  def search_bar_toggle
    classes = SEARCH_BAR_TOGGLE_CLASSES
    tag.button(
      link_icon(:minus, title: :search_bar_fewer_options.l),
      class: class_names(classes),
      type: :button,
      data: { toggle: "collapse", search_type_target: "barToggle",
              target: "#search_bar_elements" },
      aria: { expanded: "false", controls: "search_bar_elements" }
    )
  end
end
