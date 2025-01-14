# frozen_string_literal: true

module Query::Initializers::Locations
  def add_regexp_condition
    return if params[:regexp].blank?

    @title_tag = :query_title_regexp_search
    regexp = escape(params[:regexp].to_s.strip_squeeze)
    where << "locations.name REGEXP #{regexp}"
  end
end
