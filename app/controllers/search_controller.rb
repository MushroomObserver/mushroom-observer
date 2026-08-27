# frozen_string_literal: true

# searches defined by the url query string
class SearchController < ApplicationController
  # These are plural symbols because the search bar sends them this way.
  PATTERN_SEARCHABLE_MODELS = [
    :collection_numbers, :comments, :glossary_terms, :herbaria,
    :herbarium_records, :images, :locations, :names, :observations,
    :projects, :species_lists, :users
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
    else
      build_query_and_redirect(type, model_name, pattern)
    end
  end

  # An exact numeric-id (or other identifier, e.g. User's verified email)
  # match is already prioritized by the model's `pattern` scope -- see
  # AbstractModel::Scopes#exact_match_or -- so a single_result? here
  # covers both an exact match and a fuzzy search that happens to find
  # just one record.
  def build_query_and_redirect(type, model_name, pattern)
    query = query_from_pattern(model_name, pattern)

    if single_result?(query)
      redirect_to(send(:"#{type.to_s.singularize}_path", query.first_id))
    else
      redirect_to(send(:"#{type}_path", params: { q: query.q_param }))
    end
  end

  def single_result?(query)
    query.result_ids.length == 1
  end

  def flash_and_redirect_invalid_search(type)
    flash_error(:runtime_invalid.t(type: :search, value: type.inspect))
    redirect_back_or_default("/")
  end
end
