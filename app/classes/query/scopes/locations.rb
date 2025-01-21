# frozen_string_literal: true

module Query::Scopes::Locations
  def add_regexp_condition
    return if params[:regexp].blank?

    regexp = escape(params[:regexp].to_s.strip_squeeze)
    where << "locations.name REGEXP #{regexp}"

    @title_tag = :query_title_regexp_search
  end
end
