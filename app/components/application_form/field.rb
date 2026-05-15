# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Override the Field class to use our custom field components.
  # Acts as a factory/dispatcher: each method builds the matching
  # Bootstrap-styled field component for the form field.
  class Field < Superform::Rails::Form::Field
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

    # Autocompleter-specific options that should NOT go in field attributes.
    # Note: :value stays in attributes since it goes to the text/textarea field
    AUTOCOMPLETER_OPTIONS = [:find_text, :keep_text, :edit_text, :create_text,
                             :create, :create_path, :hidden_name, :hidden_value,
                             :hidden_data, :controller_data, :controller_id,
                             :map_outlet].freeze

    def autocompleter(type:, textarea: false, wrapper_options: {},
                      **attributes)
      # Extract autocompleter-specific options from attributes
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
