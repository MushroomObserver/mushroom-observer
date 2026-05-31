# frozen_string_literal: true

# Action-nav for the herbaria index page. When the user is viewing
# the nonpersonal-filtered subset, offers `ListAll` to switch to
# the full index; otherwise offers `LabeledNonpersonalIndex` to
# filter to the nonpersonal subset. Always appends `New`.
class Tab::Herbarium::Index < Tab::Collection
  def initialize(query: nil)
    super()
    @query = query
  end

  private

  def tabs
    [filter_tab, Tab::Herbarium::New.new]
  end

  def filter_tab
    if @query&.params&.dig(:nonpersonal)
      Tab::Herbarium::ListAll.new
    else
      Tab::Herbarium::LabeledNonpersonalIndex.new
    end
  end
end
