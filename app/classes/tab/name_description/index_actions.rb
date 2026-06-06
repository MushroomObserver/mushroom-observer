# frozen_string_literal: true

class Tab::NameDescription::IndexActions < Tab::Collection
  def initialize(query: nil, controller: nil)
    super()
    @query = query
    @controller = controller
  end

  private

  def tabs
    [
      Tab::RelatedQuery.for(model: Name, filter: :NameDescription,
                              current_query: @query,
                              controller: @controller)
    ].compact
  end
end
