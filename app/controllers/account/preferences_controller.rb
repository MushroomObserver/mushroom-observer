# frozen_string_literal: true

module Account
  class PreferencesController < ApplicationController
    before_action :login_required

    def edit
      load_user_licenses
      render_edit_view
    end

    def update
      load_user_licenses

      normalize_rss_type_list_param
      update_password
      update_prefs_from_form
      success = prefs_changed_successfully

      respond_to do |format|
        format.turbo_stream { render(turbo_stream: turbo_stream_flash_update) }
        format.html { render_update_response(success) }
      end
    end

    # This action handles GET requests from email links.
    # It does write to the DB.
    def no_email
      user = User.safe_find(params[:id])
      return redirect_to("/") unless permitted_user_with_valid_email_type?(user)

      @user.send(email_type_setter, false)
      if @user.save
        flash_notice(success.t(name: @user.unique_text_name))
        render_no_email(email_note)
      else
        # Probably should write a better error message here...
        flash_object_errors(@user)
        redirect_to("/")
      end
    end

    EMAIL_TYPES = %w[
      comments_owner
      comments_response
      comments_all

      observations_consensus
      observations_naming
      observations_all

      names_admin
      names_author
      names_editor
      names_reviewer
      names_all

      locations_admin
      locations_author
      locations_editor
      locations_all

      general_feature
      general_commercial
      general_question
    ].freeze

    # `back` is an enum of known destinations, not a URL -- same
    # convention as HerbariumRecordsController's `:back`. Keeps this
    # a plain lookup instead of trusting an attacker-controllable URL
    # on this public POST endpoint. Used by the plain-HTML fallback
    # path only; the turbo_stream path stays put regardless.
    BACK_DESTINATIONS = %w[rss_logs].freeze

    private

    def render_update_response(success)
      if success
        redirect_to(back_url || { action: :edit })
      else
        render_edit_view_invalid # render to get the errors to display
      end
    end

    def back_url
      key = params.permit(:back)[:back].to_s
      return nil unless BACK_DESTINATIONS.include?(key)

      case key
      when "rss_logs"
        # Same types the user just saved as their default, so the
        # page they land back on reflects it.
        activity_logs_path(q: { types: params.dig(:q, :types) })
      end
    end

    # "Save these as my defaults" on the RSS-logs filter form submits
    # the same q[types][] checkboxes the Apply button uses, not
    # user[default_rss_type] directly. Translate before the generic
    # prefs loop runs.
    def normalize_rss_type_list_param
      types = params.dig(:q, :types)
      return unless types.is_a?(Array) || types.is_a?(String)
      return if types.blank?

      params[:user] ||= {}
      params[:user][:default_rss_type] = Array(types).join(" ")
    end

    def render_edit_view(status: :ok, **render_opts)
      render(Views::Controllers::Account::Preferences::Edit.new(
               user: @user, licenses: @licenses,
               languages: Language.all.to_a
             ), status: status, **render_opts)
    end

    def render_no_email(note)
      render(Views::Controllers::Account::Preferences::NoEmail.new(
               user: @user, note: note
             ))
    end

    def load_user_licenses
      @licenses = License.available_names_and_ids(@user&.license)
    end

    def update_password
      return unless (password = params[:user]&.dig(:password))

      if password == params[:user][:password_confirmation]
        @user.change_password(password)
      else
        @user.errors.add(:password, :runtime_prefs_password_no_match)
      end
    end

    def update_prefs_from_form
      return unless params[:user]

      prefs_types.each do |pref, type|
        next unless params[:user].key?(pref)

        apply_pref(pref, type, params[:user][pref])
      end
    end

    def apply_pref(pref, type, val)
      case type
      when :string  then update_pref(pref, val.to_s.strip)
      when :integer then update_pref(pref, val.to_i)
      when :boolean then update_pref(pref, val == "1")
      when :enum    then update_pref(pref, val)
      when :content_filter then update_content_filter(pref, val)
      end
    end

    def update_pref(pref, val)
      @user.send(:"#{pref}=", val) if @user.send(pref) != val
    end

    def update_content_filter(pref, val)
      filter = Query::Filter.find(pref)
      @user.content_filter[pref] =
        if filter.type == :boolean && filter.prefs_vals.one?
          val == "1" ? filter.prefs_vals.first : filter.off_val
        else
          val.to_s
        end
    end

    def prefs_changed_successfully
      result = false
      if !@user.errors.empty? || !@user.save
        flash_object_errors(@user)
      else
        flash_notice(:runtime_prefs_success.t)
        result = true
      end
      result
    end

    # Table for converting form value to object value
    # Used by update_prefs_from_form
    def prefs_types # rubocop:disable Metrics/MethodLength
      [
        [:default_rss_type, :string],
        [:email_comments_owner, :boolean],
        [:email_comments_response, :boolean],
        [:email_general_commercial, :boolean],
        [:email_general_feature, :boolean],
        [:email_general_question, :boolean],
        [:email_html, :boolean],
        [:email_locations_admin, :boolean],
        [:email_locations_author, :boolean],
        [:email_locations_editor, :boolean],
        [:email_names_admin, :boolean],
        [:email_names_author, :boolean],
        [:email_names_editor, :boolean],
        [:email_names_reviewer, :boolean],
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
        [:label_format, :enum],
        [:login, :string],
        [:no_emails, :boolean],
        [:notes_template, :string],
        [:theme, :string],
        [:thumbnail_maps, :boolean],
        [:thumbnail_size, :enum],
        [:view_owner_id, :boolean],
        [:votes_anonymous, :enum]
      ] + content_filter_types
    end

    def content_filter_types
      Query::Filter.all.map do |fltr|
        [fltr.sym, :content_filter]
      end
    end

    def permitted_user_with_valid_email_type?(user)
      user && permission!(user) && EMAIL_TYPES.include?(email_type)
    end

    def email_type_setter
      "email_#{email_type}="
    end

    def email_msg_prefix
      "no_email_#{email_type}"
    end

    def success
      :"#{email_msg_prefix}_success"
    end

    def email_note
      :"#{email_msg_prefix}_note"
    end

    def email_type
      params[:type]
    end
  end
end
