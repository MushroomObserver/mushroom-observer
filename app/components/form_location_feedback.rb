# frozen_string_literal: true

# Displays feedback about dubious location reasons when creating/editing
# observations or species lists.
#
# @param dubious_where_reasons [Array<String>, nil] dubious reasons
# @param button [String, Symbol] button name for help text
class Components::FormLocationFeedback < Components::Base
  prop :dubious_where_reasons, _Nilable(Array), default: nil
  prop :button, _Union(String, Symbol) do |value|
    value.is_a?(Symbol) ? value.l : value
  end

  def view_template
    return unless @dubious_where_reasons&.any?

    render(
      Components::Alert.new(
        level: :warning, class: "my-3", id: "dubious_location_messages"
      )
    ) do
      div do
        @dubious_where_reasons.each_with_index do |reason, index|
          br if index.positive?
          trusted_html(reason)
        end
      end
      span(class: "help-note") do
        trusted_html(:form_observations_dubious_help.t(button: @button))
      end
    end
  end
end
