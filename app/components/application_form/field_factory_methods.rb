# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Shared factory-method surface for things that stand in as a
  # form field: the model-bound `Field` (Superform::Field subclass)
  # and the standalone `FieldProxy` (raw `name=`, no model). Each
  # method returns the matching Bootstrap-styled MO field component
  # with the includer (`self` — a Field or FieldProxy) as its
  # backing field.
  #
  # The downstream components only depend on `.dom.{id,name}`,
  # `.value`, `.key`, `.parent`, all of which both Field and
  # FieldProxy provide.
  #
  module FieldFactoryMethods
    # Autocompleter-specific options that should NOT go in field
    # attributes. `:value` stays in attributes since it goes to
    # the text/textarea field.
    AUTOCOMPLETER_OPTIONS = [:find_text, :keep_text, :edit_text,
                             :create_text, :create, :create_path,
                             :hidden_name, :hidden_value, :hidden_data,
                             :controller_data, :controller_id,
                             :map_outlet].freeze

    def text(wrapper_options: {}, **attributes)
      TextField.new(self, wrapper_options: wrapper_options, **attributes)
    end

    def textarea(wrapper_options: {}, **attributes)
      TextareaField.new(self, wrapper_options: wrapper_options, **attributes)
    end

    def file(wrapper_options: {}, **attributes)
      FileField.new(self, wrapper_options: wrapper_options, **attributes)
    end

    def checkbox(*options, wrapper_options: {}, **attributes)
      CheckboxField.new(self, *options,
                        wrapper_options: wrapper_options, **attributes)
    end

    def radio(*options, wrapper_options: {}, **attributes)
      RadioField.new(self, *options,
                     wrapper_options: wrapper_options, **attributes)
    end

    def select(options, wrapper_options: {}, **attributes)
      SelectField.new(self, collection: options,
                            wrapper_options: wrapper_options, **attributes)
    end

    def read_only(wrapper_options: {}, **attributes)
      ReadOnlyField.new(self, wrapper_options: wrapper_options, **attributes)
    end

    def autocompleter(type:, textarea: false, wrapper_options: {},
                      **attributes)
      ac_options = attributes.slice(*AUTOCOMPLETER_OPTIONS)
      field_attributes = attributes.except(*AUTOCOMPLETER_OPTIONS)

      AutocompleterField.new(self, type: type, textarea: textarea,
                                   attributes: field_attributes,
                                   wrapper_options: wrapper_options,
                                   **ac_options)
    end

    def static(wrapper_options: {}, **attributes)
      StaticTextField.new(self, wrapper_options: wrapper_options, **attributes)
    end

    def date(wrapper_options: {}, **attributes)
      DateField.new(self, wrapper_options: wrapper_options, **attributes)
    end
  end
end
