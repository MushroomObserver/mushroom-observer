# frozen_string_literal: true

# "N Observations" link on the species-list show page's action-tab
# strip -- the observations index, filtered by whatever query the
# page is already showing. `count:` comes from the page's pagination
# total, not a fresh query -- see Tab::SpeciesList::ShowActions.
class Tab::SpeciesList::Observations < Tab::Base
  def initialize(q_param: nil, count: nil)
    super()
    @q_param = q_param
    @count = count
  end

  def title
    return :observations.ti unless @count

    "#{@count} #{:observations.ti}"
  end

  def path
    observations_path(q: @q_param)
  end

  def alt_title
    "observations"
  end
end
