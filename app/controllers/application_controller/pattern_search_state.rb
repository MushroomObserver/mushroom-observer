# frozen_string_literal: true

#  ==== PatternSearchState
#  query_from_pattern::   Build a Query from a raw pattern string, using
#                         PatternSearch::<Model>'s keyword parser where
#                         one exists.
#  pattern_too_long?::    Guard + flash + redirect on an overlong pattern.
#  save_pattern_if_it_wont_overfill_cookie_store::
#                         Remember the pattern for the search bar, unless
#                         doing so would overflow the session cookie.
#
#  Shared by SearchController (the search bar's submission) and
#  ApplicationController::Indexes#pattern (a model index hit directly
#  with `?pattern=`).
#
module ApplicationController::PatternSearchState
  private

  def pattern_too_long?(pattern)
    return false if pattern.length <= Searchable::MAX_SEARCH_INPUT_LENGTH

    flash_error(
      :runtime_search_string_too_long.t(
        max: Searchable::MAX_SEARCH_INPUT_LENGTH,
        length: pattern.length
      )
    )
    redirect_back_or_to(root_path)
    true
  end

  def save_pattern_if_it_wont_overfill_cookie_store(type, pattern)
    return if session_data_size > 2048 || pattern.bytesize > 2048

    session[:pattern] = pattern
    session[:search_type] = type
  end

  # The CookieStore (Default) limit is 4096
  def session_data_size
    session.to_hash.compact.to_json.bytesize
  end

  # Convert pattern into a Query, using PatternSearch::<Model>'s keyword
  # parser where one exists (currently Location, Name, Observation);
  # otherwise a plain fuzzy `pattern:` query attr.
  def query_from_pattern(model_name, pattern)
    if (search_class = "PatternSearch::#{model_name}".safe_constantize)
      pattern_search_query_from_pattern(search_class, model_name, pattern)
    else
      create_query(model_name, pattern:)
    end
  end

  # Instantiate a PatternSearch to turn the keywords into query params and
  # catch invalid PatternSearch terms. (We can't just send a raw pattern
  # with keywords to Query as `create_query(model_name, pattern:)`)
  def pattern_search_query_from_pattern(search_class, model_name, pattern)
    search = search_class.new(pattern, @user)
    if search.errors.any?
      flash_pattern_search_errors(search)
      session[:pattern] = nil
    end
    # This will create a blank query if there are errors.
    create_query(model_name, search.query&.params || {})
  end

  def flash_pattern_search_errors(search)
    search.errors.each { |error| flash_error(error.to_s) }
  end
end
