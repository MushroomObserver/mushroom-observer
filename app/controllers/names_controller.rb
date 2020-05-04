# frozen_string_literal: true

#
#  = Names Controller
#
#  == Actions
#   L = login required
#   R = root required
#   V = has view
#   P = prefetching allowed
#
#  index_name::                  List of results of index/search.
#  index::                       Alphabetical list of all names, used or not.
#  observation_index::           Alphabetical list of names people have seen.
#  names_by_user::               Alphabetical list of names created by
#                                given user.
#  names_by_editor::             Alphabetical list of names edited by given user
#  name_search::                 Seach for string in name, notes, etc.
#  map::                         Show distribution map.
#  index_name_description::      List of results of index/search.
#  list_name_descriptions::      Alphabetical list of all name_descriptions,
#                                used or otherwise.
#  name_descriptions_by_author:: Alphabetical list of name_descriptions authored
#                                by given user.
#  name_descriptions_by_editor:: Alphabetical list of name_descriptions edited
#                                by given user.
#  show::                        Show info about name.
#  show_past_name::              Show past versions of name info.
#  show_prev::                   Show previous name in index.
#  show_next::                   Show next name in index.
#  new::                         Create new name.
#  edit::                        Edit name.
#  make_description_default::    Make a description the default one.
#  merge_descriptions::          Merge a description with another.
#  publish_description::         Publish a draft description.
#  adjust_permissions::          Adjust permissions on a description.
#  change_synonyms::             Change list of synonyms for a name.
#  deprecate_name::              Deprecate name in favor of another.
#  approve_name::                Flag given name as "accepted"
#                                (others could be, too).
#  bulk_name_edit::              Create/synonymize/deprecate a list of names.
#  edit_lifeform::               Edit lifeform tags.
#  propagate_lifeform::          Add/remove lifeform tags to/from subtaxa.
#  propagate_classification::    Copy classification to all subtaxa.
#  refresh_classification::      Refresh classification from genus.
#
#  ==== Helpers
#  deprecate_synonym::           (used by change_synonyms)
#  check_for_new_synonym::       (used by change_synonyms)
#  dump_sorter::                 Error diagnostics for change_synonyms.
#
class NamesController < ApplicationController
  require_dependency "names_controller/indexes_and_searches"
  require_dependency "names_controller/show"
  require_dependency "names_controller/create_and_edit_name"
  require_dependency "names_controller/classification"
  require_dependency "names_controller/synonymy"
  require_dependency "names_controller/eol"

  # rubocop:disable Rails/LexicallyScopedActionFilter
  # No idea how to fix this offense.  If I add another
  #    before_action :login_required, except: :show_name_description
  # in name_controller/show_name_description.rb, it ignores it.
  before_action :login_required, except: [
    :advanced_search,
    :authored_names,
    :eol,
    :eol_preview,
    :index,
    :index_name,
    :map,
    :list_names,
    :name_search,
    :names_by_user,
    :names_by_editor,
    :needed_descriptions,
    :next_name,
    :observation_index,
    :prev_name,
    :show,
    :show_next,
    :show_prev,
    :show_name,
    :show_past_name,
    :test_index
  ]
  before_action :disable_link_prefetching, except: [
  ]

  before_action :disable_link_prefetching, except: [
    :approve_name,
    :bulk_name_edit,
    :change_synonyms,
    :deprecate_name,
    :new,
    :edit,
    :show,
    :show_name,
    :show_past_name
  ]
  # rubocop:enable Rails/LexicallyScopedActionFilter

  ##############################################################################
  #
  #  :section: Other Stuff
  #
  ##############################################################################

  # Utility accessible from a number of name pages (e.g. indexes and
  # show_name?) that lets you enter a whole list of names, together with
  # synonymy, and create them all in one blow.
  def bulk_name_edit
    @list_members = nil
    @new_names    = nil
    return unless request.method == "POST"

    list = begin
             params[:list][:members].strip_squeeze
           rescue StandardError
             ""
           end
    construct_approved_names(list, params[:approved_names])
    sorter = NameSorter.new
    sorter.sort_names(list)
    if sorter.only_single_names
      sorter.create_new_synonyms
      flash_notice :name_bulk_success.t
      redirect_to(controller: :rss_logs, action: :list_rss_logs)
    else
      if sorter.new_name_strs != []
        # This error message is no longer necessary.
        if Rails.env.test?
          flash_error(
            "Unrecognized names given, including: "\
            "#{sorter.new_name_strs[0].inspect}"
          )
        end
      else
        # Same with this one... err, no this is not reported anywhere.
        flash_error(
          "Ambiguous names given, including: "\
          "#{sorter.multiple_line_strs[0].inspect}"
        )
      end
      @list_members = sorter.all_line_strs.join("\r\n")
      @new_names    = sorter.new_name_strs.uniq.sort
    end
  end

  # Draw a map of all the locations where this name has been observed.
  def map
    pass_query_params
    @name = find_or_goto_index(Name, params[:id].to_s)
    return unless @name

    @query = create_query(:Observation, :all, names: @name.id)
    apply_content_filters(@query)
    @observations = @query.results.select { |o| o.lat || o.location }
  end

  # Form accessible from show_name that lets a user setup tracker notifications
  # for a name.
  def email_tracking
    pass_query_params
    name_id = params[:id].to_s
    @name = find_or_goto_index(Name, name_id)
    return unless @name

    flavor = Notification.flavors[:name]
    @notification = Notification.
                    find_by_flavor_and_obj_id_and_user_id(flavor, name_id,
                                                          @user.id)
    if request.method != "POST"
      initialize_tracking_form
    else
      submit_tracking_form(name_id)
    end
  end

  def initialize_tracking_form
    unless @name.at_or_below_genus?
      flash_warning(:email_tracking_enabled_only_for.t(name: @name.display_name,
                                                       rank: @name.rank))
    end
    if @notification
      @note_template = @notification.note_template
    else
      @note_template = :email_tracking_note_template.l(
        species_name: @name.real_text_name,
        mailing_address: @user.mailing_address_for_tracking_template,
        users_name: @user.legal_name
      )
    end
  end

  def submit_tracking_form(name_id)
    case params[:commit]
    when :ENABLE.l, :UPDATE.l
      note_template = params[:notification][:note_template]
      note_template = nil if note_template.blank?
      if @notification.nil?
        @notification = Notification.new(flavor: :name,
                                         user: @user,
                                         obj_id: name_id,
                                         note_template: note_template)
        flash_notice(:email_tracking_now_tracking.t(name: @name.display_name))
      else
        @notification.note_template = note_template
        flash_notice(:email_tracking_updated_messages.t)
      end
      @notification.save
    when :DISABLE.l
      @notification.destroy
      flash_notice(
        :email_tracking_no_longer_tracking.t(name: @name.display_name)
      )
    end
    redirect_with_query(action: :show_name, id: name_id)
  end

  def edit_lifeform
    pass_query_params
    @name = find_or_goto_index(Name, params[:id])
    return unless request.method == "POST"

    words = Name.all_lifeforms.select do |word|
      params["lifeform_#{word}"] == "1"
    end
    @name.update(lifeform: " #{words.join(" ")} ")
    redirect_with_query(@name.show_link_args)
  end

  def propagate_lifeform
    pass_query_params
    @name = find_or_goto_index(Name, params[:id])
    return unless request.method == "POST"

    Name.all_lifeforms.each do |word|
      if params["add_#{word}"] == "1"
        @name.propagate_add_lifeform(word)
      elsif params["remove_#{word}"] == "1"
        @name.propagate_remove_lifeform(word)
      end
    end
    redirect_with_query(@name.show_link_args)
  end
end
