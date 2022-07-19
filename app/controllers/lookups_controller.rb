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
    lookup_general(Name, true)
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

  # Alternative to controller/show_object/id.  These were included for the
  # benefit of the textile wrapper: We don't want to be looking up all these
  # names and objects every time we display comments, etc.  Instead we make
  # _object_ link to these lookup_object methods, and defer lookup until the
  # user actually clicks on one.  These redirect to the appropriate
  # controller/action after looking up the object.
  # inputs: model Class, true/false
  def lookup_general(model, accepted = false)
    matches = []
    suggestions = []
    type = model.type_tag
    id = params[:id].to_s.gsub(/[+_]/, " ").strip_squeeze
    begin
      if /^\d+$/.match?(id)
        obj = find_or_goto_index(model, id)
        return unless obj

        matches = [obj]
      else
        case model.to_s
        when "Name"
          if (parse = Name.parse_name(id))
            matches = Name.where(search_name: parse.search_name)
            matches = Name.where(text_name: parse.text_name) if matches.empty?
            matches = fix_name_matches(matches, accepted)
          end
          if matches.empty?
            suggestions = Name.suggest_alternate_spellings(id)
            suggestions = fix_name_matches(suggestions, accepted)
          end
        when "Location"
          pattern = "%#{id}%"
          matches = Location.limit(100).
                    where(Location[:name].matches(pattern).
                      or(Location[:scientific_name].matches(pattern)))
        when "Project"
          pattern = "%#{id}%"
          matches = Project.limit(100).
                    where(Project[:title].matches(pattern))

        when "SpeciesList"
          pattern = "%#{id}%"
          matches = SpeciesList.limit(100).
                    where(SpeciesList[:title].matches(pattern))
        when "User"
          matches = User.where(login: id)
          matches = User.where(name: id) if matches.empty?
        end
      end
    rescue StandardError => e
      flash_error(e.to_s) unless Rails.env.production?
    end

    if matches.empty? && suggestions.empty?
      flash_error(:runtime_object_no_match.t(match: id, type: type))
      if model == User
        redirect_to("/") # (no public index for users)
      else
        redirect_to(controller: model.show_controller,
                    action: model.index_action)
      end
    elsif matches.length == 1 || suggestions.length == 1
      obj = matches.first || suggestions.first
      if suggestions.any?
        flash_warning(:runtime_suggest_one_alternate.t(match: id, type: type))
      end
      redirect_to(controller: obj.show_controller,
                  action: obj.show_action,
                  id: obj.id)
    else
      obj = matches.first || suggestions.first
      query = Query.lookup(model, :in_set, ids: matches + suggestions)
      if suggestions.any?
        flash_warning(:runtime_suggest_multiple_alternates.t(match: id,
                                                             type: type))
      else
        flash_warning(:runtime_object_multiple_matches.t(match: id,
                                                         type: type))
      end
      redirect_to(add_query_param({ controller: obj.show_controller,
                                    action: obj.index_action },
                                  query))
    end
  end

  def fix_name_matches(matches, accepted)
    matches.map do |name|
      if accepted && name.deprecated
        name.approved_synonyms.first
      else
        name.correct_spelling || name
      end
    end.compact
  end
end
