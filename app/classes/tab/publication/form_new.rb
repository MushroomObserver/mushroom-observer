# frozen_string_literal: true

# Action-nav for the publication new form.
class Tab::Publication::FormNew < Tab::Collection
  private

  def tabs
    [Tab::Publication::Index.new]
  end
end
