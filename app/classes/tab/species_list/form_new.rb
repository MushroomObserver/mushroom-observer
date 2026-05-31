# frozen_string_literal: true

# Action-nav for the new species_list form: Name Lister + cancel
# to index.
class Tab::SpeciesList::FormNew < Tab::Collection
  def initialize(q_param: nil)
    super()
    @q_param = q_param
  end

  private

  def tabs
    [
      Tab::SpeciesList::NameLister.new,
      Tab::SpeciesList::Index.new(q_param: @q_param)
    ]
  end
end
