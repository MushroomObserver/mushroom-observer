# frozen_string_literal: true

class Tab::Name::FormNew < Tab::Collection
  private

  def tabs
    [Tab::Name::Index.new]
  end
end
