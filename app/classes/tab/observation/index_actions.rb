# frozen_string_literal: true

# Action-nav for the observations index page. When the user landed
# via `?where=...`, the AtWhereActions tabs prepend; the rest are
# always shown.
class Tab::Observation::IndexActions < Tab::Collection
  def initialize(query: nil, where: nil, q_param: nil, controller: nil)
    super()
    @query = query
    @where = where
    @q_param = q_param
    @controller = controller
  end

  private

  def tabs
    [
      *at_where_tabs,
      Tab::Observation::Map.new(q_param: @q_param),
      *related_query_tabs,
      Tab::Observation::AddToList.new(q_param: @q_param),
      Tab::Observation::DownloadCSV.new(q_param: @q_param),
      Tab::Observation::InatImport.new
    ].compact
  end

  def at_where_tabs
    return [] if @where.blank?

    Tab::Observation::AtWhereActions.new(where: @where,
                                         q_param: @q_param).to_a
  end

  def related_query_tabs
    Tab::Observation::RelatedQueryActions.new(query: @query,
                                              controller: @controller).to_a
  end
end
