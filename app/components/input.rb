# frozen_string_literal: true

# MO base class for components that inherit from `Superform::Rails::
# Components::Input` (Phlex components for `<input>`-derived form
# controls). The Superform class doesn't share an inheritance line
# with `Components::Base`, so MO-side `Components::Base` registrations
# aren't inherited — subclasses (e.g. `AutocompleterField`) render
# their own children via `render(Components::X.new(...))` rather than
# calling helper bridges.
class Components::Input < Superform::Rails::Components::Input
end
