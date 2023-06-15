# frozen_string_literal: true

class LookupsController < ApplicationController
  # These need to be moved into the files where they are actually used.
  require "find"
  require "set"

  before_action :login_required, except: [
    :lookup_observation
  ]

  def lookup_comment
    lookup_general(Comment)
  end

  def lookup_image
    lookup_general(Image)
  end

  def lookup_glossary_term

  end

  def lookup_location
    lookup_general(Location)
  end

  def lookup_name
    lookup_general(Name)
  end

  # This was created in late July 2012 to give MycoPortal a safe way to link
  # back to MO's show_name pages.  In particular, it was not intended to be
  # used with a name ID.  It can actually return a deprecated name if you give
  # it a name ID.  This is, of course, bizarre behavior, but we're ignoring it
  # because it should never be called that way in the first place. -JPH 1/2017
  def lookup_accepted_name
    lookup_general(Name, accepted: true)
  end

  def lookup_observation
    lookup_general(Observation)
  end

  def lookup_project
    lookup_general(Project)
  end

  def lookup_species_list
    lookup_general(SpeciesList)
  end

  def lookup_user
    lookup_general(User)
  end

  ##############################################################################

  private

  # Alternative to controller/show_object/id.  These were included for the
  # benefit of the textile wrapper: We don't want to be looking up all these
  # names and objects every time we display comments, etc.  Instead we make
  # _object_ link to these lookup_object methods, and defer lookup until the
  # user actually clicks on one.  These redirect to the appropriate
  # controller/action after looking up the object.
  # inputs: model Class, true/false
  def lookup_general(model, accepted: false)
    id = params[:id].to_s.gsub(/[+_]/, " ").strip_squeeze

    matches, suggestions = find_matches_and_suggestions(model, id, accepted)
    return if /^\d+$/.match?(id) && !matches

    handle_matches_and_suggestions(
      model: model, id: id, matches: matches, suggestions: suggestions
    )
  end

  def find_matches_and_suggestions(model, id, accepted)
    return find_integer_matches(model, id) if /^\d+$/.match?(id)

    case model.to_s
    when "Name"
      find_name_matches_and_suggestions(id, accepted)
    when "Location"
      find_location_matches(id)
    when "Project"
      find_project_matches(id)
    when "SpeciesList"
      find_species_list_matches(id)
    when "User"
      find_user_matches(id)
    end
  end

  def find_integer_matches(model, id)
    begin
      obj = find_or_goto_index(model, id)
    rescue StandardError => e
      flash_error(e.to_s) unless Rails.env.production?
    end

    return nil unless obj

    [[obj], nil]
  end

  def find_name_matches_and_suggestions(id, accepted)
    matches = find_name_matches(id, accepted)
    return [matches, []] unless matches.empty?

    suggestions = []
    begin
      suggestions = Name.suggest_alternate_spellings(id)
      suggestions = fix_name_matches(suggestions, accepted) if suggestions.any?
    rescue StandardError => e
      flash_error(e.to_s) unless Rails.env.production?
    end

    [[], suggestions]
  end

  def find_name_matches(id, accepted)
    matches = []

    begin
      parse = Name.parse_name(id)
      if parse
        matches = Name.where(search_name: parse.search_name)
        matches = Name.where(text_name: parse.text_name) if matches.empty?
        matches = fix_name_matches(matches, accepted)
      end
    rescue StandardError => e
      flash_error(e.to_s) unless Rails.env.production?
    end

    matches
  end

  def fix_name_matches(matches, accepted)
    matches.filter_map do |name|
      if accepted && name.deprecated
        name.approved_synonyms.first
      else
        name.correct_spelling || name
      end
    end
  end

  def find_location_matches(id)
    pattern = "%#{id}%"

    begin
      matches = Location.limit(100).
                where(Location[:name].matches(pattern).
                or(Location[:scientific_name].matches(pattern)))
    rescue StandardError => e
      flash_error(e.to_s) unless Rails.env.production?
    end

    [matches, []]
  end

  def find_project_matches(id)
    pattern = "%#{id}%"

    begin
      matches = Project.limit(100).
                where(Project[:title].matches(pattern))
    rescue StandardError => e
      flash_error(e.to_s) unless Rails.env.production?
    end

    [matches, []]
  end

  def find_species_list_matches(id)
    pattern = "%#{id}%"

    begin
      matches = SpeciesList.limit(100).
                where(SpeciesList[:title].matches(pattern))
    rescue StandardError => e
      flash_error(e.to_s) unless Rails.env.production?
    end

    [matches, []]
  end

  def find_user_matches(id)
    begin
      matches = User.where(login: id)
      matches = User.where(name: id) if matches.empty?
    rescue StandardError => e
      flash_error(e.to_s) unless Rails.env.production?
    end

    [matches, []]
  end

  def handle_matches_and_suggestions(model:, id:, matches:, suggestions:)
    if matches.empty? && suggestions.empty?
      handle_no_match(model, id)
    elsif matches.length == 1 || suggestions&.length == 1
      handle_single_match_or_suggestion(
        model: model, id: id, matches: matches, suggestions: suggestions
      )
    else
      handle_multiple_matches_or_suggestions(
        model: model, id: id, matches: matches, suggestions: suggestions
      )

    end
  end

  def handle_no_match(model, id)
    flash_error(:runtime_object_no_match.t(match: id, type: model.type_tag))
    if model == User
      redirect_to("/")
    else
      redirect_to(controller: model.show_controller, action: model.index_action)
    end
  end

  def handle_single_match_or_suggestion(model:, id:, matches:, suggestions:)
    obj = matches.first || suggestions.first
    if suggestions.any?
      flash_warning(
        :runtime_suggest_one_alternate.t(match: id, type: model.type_tag)
      )
    end
    redirect_to(controller: obj.show_controller,
                action: obj.show_action,
                id: obj.id)
  end

  def handle_multiple_matches_or_suggestions(
    model:, id:, matches:, suggestions:
  )
    obj = matches.first || suggestions.first
    query = Query.lookup(model, :in_set, ids: matches + suggestions)
    if suggestions.any?
      flash_warning(
        :runtime_suggest_multiple_alternates.t(match: id, type: model.type_tag)
      )
    else
      flash_warning(
        :runtime_object_multiple_matches.t(match: id, type: model.type_tag)
      )
    end
    redirect_to(add_query_param({ controller: obj.show_controller,
                                  action: obj.index_action },
                                query))
  end
end
