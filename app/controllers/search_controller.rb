# frozen_string_literal: true

# searches defined by the url query string
class SearchController < ApplicationController
  # These are plural symbols because the search bar sends them this way.
  PATTERN_SEARCHABLE_MODELS = [
    :comments, :glossary_terms, :herbaria, :herbarium_records, :images,
    :locations, :names, :observations, :projects, :species_lists, :users
  ].freeze

  # This is the action the search bar commits to.
  # It creates a query and forwards that to the appropriate index as :q.
  def pattern
    pattern = params.dig(:pattern_search, :pattern).to_s.strip_squeeze
    type = params.dig(:pattern_search, :type)
    # safe pluralize in case session[:search_type] is singular
    type = type.to_s.pluralize.to_sym unless type == :google

    unless (PATTERN_SEARCHABLE_MODELS + [:google]).include?(type)
      flash_and_redirect_invalid_search(type)
      return
    end

    return if pattern_too_long?(pattern)

    save_pattern_and_proceed(type, pattern)
  end

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

  def save_pattern_and_proceed(type, pattern)
    # Save it so that we can keep it in the search bar in subsequent pages.
    # But don't save encoded incoming patterns that are too large.
    save_pattern_if_it_wont_overfill_cookie_store(type, pattern)

    if type == :google
      site_google_search(pattern)
    else
      forward_pattern_search(type, pattern)
    end
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

  def site_google_search(pattern)
    if pattern.blank?
      redirect_to("/")
    else
      search = URI.encode_www_form(q: "site:#{MO.domain} #{pattern}")
      redirect_to("https://google.com/search?#{search}")
    end
  end

  # Convert pattern into :q here, so we hit the index with a standard permalink
  # and have a saved query that we can refine in a search form.
  def forward_pattern_search(type, pattern)
    model_name = type.to_s.singularize.camelize.to_sym

    if pattern.blank?
      redirect_to(send(:"#{type}_path"))
    elsif (obj = exact_match(model_name, pattern))
      redirect_to(send(:"#{type.to_s.singularize}_path", obj.id))
    else
      build_query_and_redirect(type, model_name, pattern)
    end
  end

  # If pattern is an identifier, redirect to the show page for that object.
  def exact_match(model_name, pattern)
    case model_name
    when :User
      user_exact_match(pattern)
    else
      maybe_pattern_is_an_id(model_name, pattern)
    end
  end

  def user_exact_match(pattern)
    if ((pattern.match?(/^\d+$/) && (user = User.safe_find(pattern))) ||
       # (user = User.find_by(login: pattern)) ||
       # (user = User.find_by(name: pattern)) ||
       (user = User.find_by(email: pattern))) && user.verified
      return user
    end

    false
  end

  def maybe_pattern_is_an_id(model_name, pattern)
    if /^\d+$/.match?(pattern)
      return model_name.to_s.constantize.safe_find(pattern)
    end

    false
  end

  def build_query_and_redirect(type, model_name, pattern)
    # :Name, :Observation, and :Location prevalidate the pattern with a
    # PatternSearch instance, and check for errors defined by PatternSearch.
    query = query_from_pattern(model_name, pattern)

    # Finally we can redirect.
    if coming_from_obs_needing_ids?(model_name)
      redirect_to(identify_observations_path(q: query.q_param))
    elsif single_result?(query)
      redirect_to(send(:"#{type.to_s.singularize}_path", query.first_id))
    else
      redirect_to(send(:"#{type}_path", params: { q: query.q_param }))
    end
  end

  def coming_from_obs_needing_ids?(model_name)
    model_name == :Observation && params[:needs_naming]
  end

  def single_result?(query)
    query.result_ids.length == 1
  end

  def query_from_pattern(model_name, pattern)
    case model_name
    when :Observation, :Name, :Location
      pattern_search_query_from_pattern(model_name, pattern)
    else
      create_query(model_name, pattern:)
    end
  end

  # Instantiate a PatternSearch to turn the keywords into query params and
  # catch invalid PatternSearch terms. (We can't just send a raw pattern with
  # keywords to Query as `create_query(model_name, pattern:)`)
  def pattern_search_query_from_pattern(model_name, pattern)
    search = "PatternSearch::#{model_name}".constantize.new(pattern)
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

  def flash_and_redirect_invalid_search(type)
    flash_error(:runtime_invalid.t(type: :search, value: type.inspect))
    redirect_back_or_default("/")
  end
end
