# frozen_string_literal: true

# MO base class for components that inherit from `Superform::Rails::
# Components::Input` (Phlex components for `<input>`-derived form
# controls). The Superform class doesn't share an inheritance line
# with `Components::Base`, so MO output-helper registrations on
# `Components::Base` aren't inherited — every MO-side Input
# subclass that needs them has to either register them itself or
# inherit from a base class that does. This is that base class.
#
# Registers the MO output helpers Input-derived field components
# typically need (`link_icon`, `icon_link_to`, `modal_link_to`) so
# subclasses can call them without per-class duplication.
class Components::Input < Superform::Rails::Components::Input
  register_output_helper :link_icon
  register_output_helper :icon_link_to
  register_output_helper :modal_link_to
end
