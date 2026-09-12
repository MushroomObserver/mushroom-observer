# frozen_string_literal: true

# "Cancel to observations index" action-nav link.
class Tab::Observation::Index < Tab::Base
  def initialize(index_filter: nil)
    super()
    @index_filter = index_filter
  end

  def title
    :cancel_to_index.t(type: :observation)
  end

  def path
    with_index_filter(observations_path, @index_filter)
  end
end
