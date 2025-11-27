# frozen_string_literal: true

class Components::ApplicationForm < Superform::Rails::Form
  # Helper methods for prefilling autocompleter fields with display values
  # when the stored values are IDs.
  #
  # @example Include in a form
  #   class MyForm < Components::ApplicationForm
  #     include AutocompleterPrefill
  #
  #     def some_method
  #       prefilled_autocompleter_value(field_value(:user_id), :user)
  #     end
  #   end
  module AutocompleterPrefill
    # Maps field names to their autocompleter types
    # Override in including class if needed
    def autocompleter_type(field_name)
      case field_name
      when :project_lists
        :project
      when :lookup
        :name
      when :by_users, :by_editor, :members
        :user
      when :within_locations
        :location
      else
        field_name.to_s.singularize.to_sym
      end
    end

    # Returns prefilled value(s) for an autocompleter field
    # Converts IDs to display names for better UX
    def prefilled_autocompleter_value(values, type)
      return values unless values.is_a?(Array)

      prefill_string_values(values, type)
    end

    # Returns comma-separated IDs for the hidden field
    def prefilled_hidden_value(values)
      return nil unless values.is_a?(Array)

      values.join(",")
    end

    private

    def prefill_string_values(values, type)
      values.map do |val|
        if numeric_value?(val)
          prefill_via_id(val, type)
        else
          val
        end
      end.join("\n")
    end

    def numeric_value?(val)
      val.is_a?(Numeric) ||
        (val.is_a?(String) && val.match(/^-?(\d+(\.\d+)?|\.\d+)$/))
    end

    def prefill_via_id(val, type)
      lookup_name = type.to_s.camelize.pluralize
      lookup = "Lookup::#{lookup_name}".constantize
      title_method = type == :user ? :unique_text_name : lookup::TITLE_METHOD
      model_class = lookup_name.singularize.constantize
      model_class.find(val.to_i).send(title_method)
    rescue ActiveRecord::RecordNotFound
      val
    end
  end
end
