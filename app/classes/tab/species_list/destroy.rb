# frozen_string_literal: true

# Renders as a destroy button — `html_options[:button] = :destroy`
# routes the consumer (`add_context_nav` → `destroy_button`) to use
# the model itself as `target:`, so `#path` returns the list instance.
class Tab::SpeciesList::Destroy < Tab::Base
  def initialize(list:)
    super()
    @list = list
  end

  def title
    :species_list_show_destroy.t
  end

  def path
    @list
  end

  def html_options
    { button: :destroy }
  end

  def model
    @list
  end
end
