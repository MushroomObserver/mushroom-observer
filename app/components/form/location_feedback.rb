# frozen_string_literal: true

# Displays feedback about dubious location reasons when creating/editing
# observations, species lists, or locations.
#
# @param dubious_where_reasons [Array<[Symbol, Hash]>, nil] unresolved
#   [tag, args] pairs from Location.dubious_reasons_for -- resolved here,
#   not on the model, since API2::Helpers needs the same data in a
#   different final form (#4901).
# @param button [String, Symbol] button name for help text
class Components::Form::LocationFeedback < Components::Base
  prop :dubious_where_reasons, _Nilable(_Array(_Tuple(Symbol, Hash))),
       default: nil
  prop :button, _Union(String, Symbol) do |value|
    value.is_a?(Symbol) ? value.l : value
  end

  def view_template
    return unless @dubious_where_reasons&.any?

    Alert(
      level: :warning, class: "my-3", id: "dubious_location_messages"
    ) do
      div do
        @dubious_where_reasons.each_with_index do |reason, index|
          br if index.positive?
          tag, args = reason
          trusted_html(tag.t(**args))
        end
      end
      Help(element: :span,
           content: :form_observations_dubious_help.t(button: @button))
    end
  end
end
