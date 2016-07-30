class Query::ObservationAll < Query::Observation
  def title
    if by = params[:by]
      by = :"sort_by_#{by}"
      title_args[:tag] ||= :query_title_all_by
      title_args[:order] = by.t
    else
      title_args[:tag] ||= :query_title_all
    end
  end
end
