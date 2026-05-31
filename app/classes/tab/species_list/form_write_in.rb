# frozen_string_literal: true

# Action-nav for the write-in form: just a "cancel and show" link
# back to the species_list show page.
class Tab::SpeciesList::FormWriteIn < Tab::Collection
  def initialize(list:)
    super()
    @list = list
  end

  private

  def tabs
    [Tab::SpeciesList::CancelToShow.new(list: @list)]
  end
end
