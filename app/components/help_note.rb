# frozen_string_literal: true

# Help note component - styled span/div/p element with help text
#
# @example
#   HelpNote("This is a note")
#   HelpNote("Important", element: :div, class: "custom-class")
class Components::HelpNote < Components::Base
  prop :content, String
  prop :element, Symbol, default: :span
  prop :extra_class, String, default: ""

  def view_template
    public_send(@element, class: class_names("help-note mr-3", @extra_class)) do
      @content
    end
  end
end
