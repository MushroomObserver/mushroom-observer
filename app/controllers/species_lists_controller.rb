# frozen_string_literal: true
#
#  = Species List Controller
#
#  == Actions
#
#  index::                   List of lists by date.
#  index_species_list::      List of lists in current query.
#  species_lists_by_title::  List of lists by title.
#  species_lists_by_user::   List of lists created by user.
#  species_list_search::     List of lists matching search.
#
#  show::                    Display notes/etc. and list of species.
#  show_next::               Display next species list in index.
#  show_prev::               Display previous species list in index.
#
#  make_report::             Display contents of species list as report.
#
#  name_lister::             Efficient javascripty way to build a list of names.
#  create::                  Create new list.
#  edit::                    Edit existing list.
#  upload_species_list::     Same as edit_species_list but gets list from file.
#  destroy::                  Destroy list.
#  add_remove_observations:: Add/remove query results to/from a list.
#  manage_species_lists::    Add/remove one observation from a user's lists.
#  add_observation_to_species_list::      (post method)
#  remove_observation_from_species_list:: (post method)
#  bulk_editor::             Bulk edit observations in species list.
#
#  *NOTE*: There is some ambiguity between observations and names that makes
#  this slightly confusing.  The end result of a species list is actually a
#  list of Observation's, not Name's.  However, creation and editing is
#  generally accomplished via Name's alone (although see manage_species_lists
#  for the one exception).  In the end all these Name's cause rudimentary
#  Observation's to spring into existence.
#
class SpeciesListsController < ApplicationController
  # require "rtf"
  require_dependency "species_lists/show"
  require_dependency "species_lists/indexes_and_searches"
  require_dependency "species_lists/create_and_edit"
  require_dependency "species_lists/observations"
  require_dependency "species_lists/projects"
  require_dependency "species_lists/helpers"

  before_action :login_required, except: [
    :index,
    :index_species_list,
    :list_species_lists, # aliased
    :make_report,
    :name_lister,
    :next_species_list, # aliased
    :prev_species_list, # aliased
    :show,
    :show_next,
    :show_prev,
    :show_species_list, # aliased
    :species_list_search,
    :species_lists_by_title,
    :species_lists_by_user,
    :species_lists_for_project
  ]

  before_action :disable_link_prefetching, except: [
    :create_species_list, # aliased
    :edit,
    :edit_species_list, # aliased
    :add_remove_observations,
    :manage_species_lists,
    :new,
    :show,
    :show_species_list # aliased
  ]

  before_action :require_successful_user, only: [
    :create,
    :create_species_list, # aliased
    :name_lister
  ]
end
