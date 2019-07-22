# frozen_string_literal: true

# see app/controllers/name_controller.rb
class NameController
  before_action :disable_link_prefetching, except: [
    :create_name,
    :edit_name
  ]

  def create_name
    store_location
    pass_query_params
    init_create_name_form
    if request.method == "POST"
      @parse = parse_name
      make_sure_name_doesnt_exist!
      create_new_name
    end
  rescue RuntimeError => e
    reload_name_form_on_error(e)
  end

  def edit_name
    store_location
    pass_query_params
    @name = find_or_goto_index(Name, params[:id].to_s)
    return unless @name

    init_edit_name_form
    if request.method == "POST"
      @parse = parse_name
      match = check_for_matches if name_unlocked?
      if match
        merge_names(match)
      else
        change_existing_name
      end
    end
  rescue RuntimeError => e
    reload_name_form_on_error(e)
  end

  # ----------------------------------------------------------------------------

  private

  def init_create_name_form
    @name = Name.new
    @name.rank = :Species
    @name_string = ""
  end

  def init_edit_name_form
    if !params[:name]
      @misspelling      = @name.is_misspelling?
      @correct_spelling = if @misspelling
                            @name.correct_spelling.real_search_name
                          else
                            ""
                          end
    else
      @misspelling      = params[:name][:misspelling] == "1"
      @correct_spelling = params[:name][:correct_spelling].to_s.strip_squeeze
    end
    @name_string = @name.real_text_name
  end

  def reload_name_form_on_error(err)
    flash_error(err.to_s) if err.present?
    flash_object_errors(@name)
    @name.locked     = params[:name][:locked]
    @name.rank       = params[:name][:rank]
    @name.author     = params[:name][:author]
    @name.citation   = params[:name][:citation]
    @name.notes      = params[:name][:notes]
    @name.deprecated = params[:name][:deprecated] == "true"
    @name_string     = params[:name][:text_name]
  end

  def create_new_name
    @name = Name.new_name_from_parsed_name(@parse)
    set_locked_citation_and_notes
    unless @name.save_with_log(:log_name_updated)
      raise(:runtime_unable_to_save_changes.t)
    end

    flash_notice(:runtime_create_name_success.t(name: @name.real_search_name))
    update_ancestors
    redirect_to_show_name
  end

  def change_existing_name
    any_changes = perform_change_existing_name
    if status_changing?
      redirect_to_approve_or_deprecate
    else
      flash_warning(:runtime_edit_name_no_change.t) unless any_changes
      redirect_to_show_name
    end
  end

  def perform_change_existing_name
    update_correct_spelling
    set_name_author_and_rank
    set_locked_citation_and_notes
    if !@name.changed?
      any_changes = false
    elsif !@name.save_with_log(:log_name_updated)
      raise(:runtime_unable_to_save_changes.t)
    else
      flash_notice(:runtime_edit_name_success.t(name: @name.real_search_name))
      any_changes = true
    end
    # Update ancestors regardless whether name changed; maybe this will add
    # missing ancestors in case database is messed up
    update_ancestors
    any_changes
  end

  def merge_names(new_name)
    if in_admin_mode? || @name.mergeable? || new_name.mergeable?
      perform_merge_names(new_name)
      redirect_to_show_name
    else
      redirect_to_merge_request(new_name)
    end
  end

  def perform_merge_names(new_name)
    old_display_name_for_log = @name[:display_name]
    @name.attributes = @parse.params
    set_locked_citation_and_notes
    # Only change deprecation status if user explicity requested it.
    if @name.deprecated != (params[:name][:deprecated] == "true")
      change_deprecated = !@name.deprecated
    end
    # Automatically swap names if that's a safer merge.
    if !@name.mergeable? && new_name.mergeable?
      @name, new_name = new_name, @name
      old_display_name_for_log = @name[:display_name]
    end
    # Fill in author if other has one.
    if new_name.author.blank? && @parse.author.present?
      new_name.change_author(@parse.author)
    end
    new_name.change_deprecated(change_deprecated) unless change_deprecated.nil?
    @name.display_name = old_display_name_for_log
    new_name.merge(@name)
    args = { this: @name.real_search_name, that: new_name.real_search_name }
    flash_notice(:runtime_edit_name_merge_success.t(args))
    @name = new_name
    @name.save
  end

  def set_name_author_and_rank
    return unless name_unlocked?

    email_admin_name_change unless minor_change? || just_adding_author?
    @name.attributes = @parse.params
  end

  def set_locked_citation_and_notes
    @name.locked   = params[:name][:locked].to_s == "1" if in_admin_mode?
    @name.citation = params[:name][:citation].to_s.strip_squeeze
    @name.notes    = params[:name][:notes].to_s.strip
  end

  # Update the misspelling status.
  #
  # @name::             Name whose status we're changing.
  # @misspelling::      Boolean: is the "this is misspelt" box checked?
  # @correct_spelling:: String: the correct name, as entered by the user.
  #
  # 1) If the checkbox is unchecked, and name used to be misspelt, then it
  #    clears correct_spelling_id.
  # 2) Otherwise, if the text field is filled in it looks up the name and
  #    sets correct_spelling_id.
  #
  # All changes are made (but not saved) to +@name+.  It returns true if
  # everything went well.  If it couldn't recognize the correct name, it
  # changes nothing and raises a RuntimeError.
  #
  def update_correct_spelling
    return unless name_unlocked?

    if @name.is_misspelling? && (!@misspelling || @correct_spelling.blank?)
      @name.correct_spelling = nil
    elsif @correct_spelling.present?
      set_correct_spelling
    end
  end

  def set_correct_spelling
    correct_name = Name.find_names_filling_in_authors(@correct_spelling).first
    raise(:runtime_form_names_misspelling_bad.t) unless correct_name
    raise(:runtime_form_names_misspelling_same.t) if correct_name.id == @name.id

    @name.mark_misspelled(correct_name)
    # (This tells it not to redirect to "approve".)
    params[:name][:deprecated] = "true"
  end

  def update_ancestors
    Name.find_or_create_parsed_name_and_parents(@parse).each do |name|
      name.save_with_log(:log_name_created) if name&.new_record?
    end
  end

  def parse_name
    text_name = params[:name][:text_name]
    text_name = @name.real_text_name if text_name.blank? && @name
    author = params[:name][:author]
    in_str = Name.clean_incoming_string("#{text_name} #{author}")
    in_rank = params[:name][:rank].to_sym
    old_deprecated = @name ? @name.deprecated : false
    parse = Name.parse_name(in_str, rank: in_rank, deprecated: old_deprecated)
    if !parse || parse.rank != in_rank
      rank_tag = :"rank_#{in_rank.to_s.downcase}"
      raise(:runtime_invalid_for_rank.t(rank: rank_tag, name: in_str))
    end
    parse
  end

  def make_sure_name_doesnt_exist!
    matches = Name.names_matching_desired_new_name(@parse)
    if matches.one?
      raise(:runtime_name_create_already_exists.
              t(name: matches.first.display_name))
    elsif matches.many?
      raise(:create_name_multiple_names_match.t(str: @parse.real_search_name))
    end
  end

  def check_for_matches
    matches = Name.where(search_name: @parse.search_name) - [@name]
    return matches.first unless matches.many?

    args = {
      str: @parse.real_search_name,
      matches: new_name.map(&:search_name).join(" / ")
    }
    raise(:edit_name_multiple_names_match.t(args))
  end

  def status_changing?
    params[:name][:deprecated].to_s != @name.deprecated.to_s
  end

  def name_unlocked?
    in_admin_mode? || !@name.locked
  end

  def minor_change?
    old_name = @name.real_search_name
    new_name = @parse.real_search_name
    new_name.percent_match(old_name) > 0.9
  end

  def just_adding_author?
    @name.author.blank? && @parse.text_name == @name.text_name
  end

  def email_admin_name_change
    subject = "Nontrivial Name Change"
    content = :email_name_change.l(
      user: @user.login,
      old: @name.real_search_name,
      new: @parse.real_search_name,
      observations: @name.observations.length,
      namings: @name.namings.length,
      url: "#{MO.http_domain}/name/show_name/#{@name.id}"
    )
    WebmasterEmail.build(@user.email, content, subject).deliver_now
    NameControllerTest.report_email(content) if Rails.env.test?
  end

  def redirect_to_show_name
    redirect_with_query(@name.show_link_args)
  end

  def redirect_to_approve_or_deprecate
    if params[:name][:deprecated].to_s == "true"
      redirect_with_query(action: :deprecate_name, id: @name.id)
    else
      redirect_with_query(action: :approve_name, id: @name.id)
    end
  end

  def redirect_to_merge_request(new_name)
    redirect_with_query(controller: :observer, action: :email_merge_request,
                        type: :Name, old_id: @name.id, new_id: new_name.id)
  end
end
