# frozen_string_literal: true

class Account::PreferencesController < ApplicationController
  before_action :login_required

  def edit
    get_user_licenses
  end

  def update
    get_user_licenses

    update_password
    update_prefs_from_form
    # call render to get the errors to display
    render(:edit) and return unless prefs_changed_successfully

    update_copyright_holder(@user.legal_name_change)
    redirect_to(edit_account_preferences_path) and return
  end

  private

  def get_user_licenses
    @licenses = License.current_names_and_ids(@user&.license)
  end

  # Table for converting form value to object value
  # Used by update_prefs_from_form
  def prefs_types # rubocop:disable Metrics/MethodLength
    [
      [:email_comments_all, :boolean],
      [:email_comments_owner, :boolean],
      [:email_comments_response, :boolean],
      [:email_general_commercial, :boolean],
      [:email_general_feature, :boolean],
      [:email_general_question, :boolean],
      [:email_html, :boolean],
      [:email_locations_admin, :boolean],
      [:email_locations_all, :boolean],
      [:email_locations_author, :boolean],
      [:email_locations_editor, :boolean],
      [:email_names_admin, :boolean],
      [:email_names_all, :boolean],
      [:email_names_author, :boolean],
      [:email_names_editor, :boolean],
      [:email_names_reviewer, :boolean],
      [:email_observations_all, :boolean],
      [:email_observations_consensus, :boolean],
      [:email_observations_naming, :boolean],
      [:email, :string],
      [:hide_authors, :enum],
      [:image_size, :enum],
      [:keep_filenames, :enum],
      [:layout_count, :integer],
      [:license_id, :integer],
      [:locale, :string],
      [:location_format, :enum],
      [:login, :string],
      [:notes_template, :string],
      [:theme, :string],
      [:thumbnail_maps, :boolean],
      [:thumbnail_size, :enum],
      [:view_owner_id, :boolean],
      [:votes_anonymous, :enum]
    ] + content_filter_types
  end

  def content_filter_types
    ContentFilter.all.map do |fltr|
      [fltr.sym, :content_filter]
    end
  end

  def update_password
    return unless (password = params["user"]["password"])

    if password == params["user"]["password_confirmation"]
      @user.change_password(password)
    else
      @user.errors.add(:password, :runtime_prefs_password_no_match.t)
    end
  end

  def update_prefs_from_form
    prefs_types.each do |pref, type|
      val = params[:user][pref]
      case type
      when :string  then update_pref(pref, val.to_s)
      when :integer then update_pref(pref, val.to_i)
      when :boolean then update_pref(pref, val == "1")
      when :enum    then update_pref(pref, val)
      when :content_filter then update_content_filter(pref, val)
      end
    end
  end

  def update_pref(pref, val)
    @user.send("#{pref}=", val) if @user.send(pref) != val
  end

  def update_content_filter(pref, val)
    filter = ContentFilter.find(pref)
    @user.content_filter[pref] =
      if filter.type == :boolean && filter.prefs_vals.count == 1
        val == "1" ? filter.prefs_vals.first : filter.off_val
      else
        val.to_s
      end
  end

  def update_copyright_holder(legal_name_change = nil)
    return unless legal_name_change

    Image.update_copyright_holder(*legal_name_change, @user)
  end

  def prefs_changed_successfully
    result = false
    if !@user.changed
      flash_notice(:runtime_no_changes.t)
    elsif !@user.errors.empty? || !@user.save
      flash_object_errors(@user)
    else
      flash_notice(:runtime_prefs_success.t)
      result = true
    end
    result
  end
end
