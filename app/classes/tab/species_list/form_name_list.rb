# frozen_string_literal: true

# Action-nav for the Name Lister form: a "create species list"
# action link.
class Tab::SpeciesList::FormNameList < Tab::Collection
  private

  def tabs
    [Tab::SpeciesList::Create.new]
  end
end
