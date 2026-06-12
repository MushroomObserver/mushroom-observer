# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Override the Field class to use our custom field components.
  # Acts as a factory/dispatcher: each method builds the matching
  # Bootstrap-styled field component for the form field. The
  # factory methods themselves live in `FieldFactoryMethods` so
  # the same surface is shared with `FieldProxy` (the non-bound
  # equivalent).
  class Field < Superform::Rails::Form::Field
    include FieldFactoryMethods
  end
end
