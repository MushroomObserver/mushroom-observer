# frozen_string_literal: true

# Action-nav for the license new form.
class Tab::License::FormNew < Tab::Collection
  private

  def tabs
    [Tab::License::Index.new]
  end
end
