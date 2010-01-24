#
#  Views: ("*" - login required, "R" - root required))
#     signup
#     welcome
#     verify
#     reverify
#     send_verify
#     login
#     logout_user
#     email_new_password
#
#   * prefs
#   * profile
#   * remove_image
#   * no_email_xxx      Callbacks from email to turn off various types of email.
#   * show_alert
#
#  Admin Tools:
#   R turn_admin_on
#   R turn_admin_off
#   R destroy_user
#   R add_user_to_group
#   R create_alert
#
#  Test Views:
#     test_flash
#
#  Helpers:
#    hide_params(obj, out, prefix)
#
################################################################################

class AccountController < ApplicationController
  before_filter :login_required, :except => [
    :email_new_password,
    :login,
    :logout_user,
    :reverify,
    :show_alert,
    :send_verify,
    :signup,
    :test_flash,
    :verify,
    :welcome,
  ]

  before_filter :disable_link_prefetching, :except => [
    :login,
    :signup,
    :prefs,
    :profile,
    :show_alert,
    :create_alert,
  ]

  def login
    if request.method != :post
      @login = ""
      @remember = true
    else
      login = params['user_login']
      password = params['user_password']
      @user = User.authenticate(login, password)
      @user = User.authenticate(login, password.strip) if !@user
      @remember = params['user'] && params['user']['remember_me'] == "1"
      if set_session_user(@user)
        logger.warn("%s, %s, %s" % [@user.login, params['user_login'], params['user_password']])
        flash_notice :login_success.t
        @user.last_login = now = Time.now
        @user.modified   = now
        @user.save
        Transaction.login_user(:id => @user)
        if @remember
          set_autologin_cookie(@user)
        else
          clear_autologin_cookie
        end
        flash[:params] = params
        redirect_back_or_default(:action => "welcome")
      else
        @login = params['user_login']
        flash_error :login_failed.t
      end
    end
    @hiddens = []
    if flash[:params]
      flash[:params].each do |obj,val|
        hide_params(val, @hiddens, obj.to_s) if val.is_a?(Hash)
      end
    end
  end

  # Parameters from page that redirected to login are preserved in
  # flash[:params].  I store them in the login page as hidden fields.  When
  # user logs in, it puts these params back into flash[:params] and redirects
  # to the original page.  The login_required "before" filter will then merge
  # them back into params[] automatically.  This method flattens the params
  # structure into a simple array.
  def hide_params(obj, out, prefix)
    if !obj.is_a?(Hash)
      id    = prefix.gsub(/\[/, "_").gsub(/\]/, "")
      name  = prefix
      value = obj.to_s
      out << [id, name, value]
    else
      obj.each do |k,v|
        hide_params(v, out, "#{prefix}[#{k.to_s}]")
      end
    end
  end

  def signup
    if request.method != :post
      @new_user = User.new
    else
      theme = params['new_user']['theme']
      login = params['new_user']['login']
      valid_themes = CSS + ["NULL"]
      if valid_themes.member?(theme) and (login != 'test_denied')
        @new_user = User.new(params['new_user'])
        @new_user.created         = now = Time.now
        @new_user.modified        = now
        @new_user.last_login      = now
        @new_user.admin           = false
        @new_user.created_here    = true
        @new_user.rows            = 5
        @new_user.columns         = 3
        @new_user.mailing_address = ''
        @new_user.notes           = ''
        if @new_user.save
          Transaction.post_user(
            :id    => @new_user,
            :name  => @new_user.name,
            :email => @new_user.email,
            :login => @new_user.login
          )
          flash_notice :signup_success.t
          AccountMailer.deliver_verify(@new_user)
          redirect_back_or_default(:action => "welcome")
        else
          flash_object_errors(@new_user)
        end
      else
        if theme.strip != ''
          AccountMailer.deliver_denied(params['new_user'])
        end
        redirect_back_or_default(:action => "welcome")
      end
    end
  end

  def email_new_password
    if request.method != :post
      @new_user = User.new
    else
      @login = params['new_user']['login']
      @new_user = User.find(:first, :conditions => [ "login = ? OR name = ? OR email = ?",
                                                     @login, @login, @login ])
      if @new_user.nil?
        flash_error :email_new_password_failed.t(:user => @login)
      else
        password = String.random(10)
        @new_user.change_password(password)
        if @new_user.save
          flash_notice :email_new_password_success.t(:email => @new_user.email)
          AccountMailer.deliver_new_password(@new_user, password)
          @hiddens = []
          render(:action => "login")
        else
          flash_object_errors(@new_user)
        end
      end
    end
  end

  def prefs
    if @user
      @licenses = License.current_names_and_ids(@user.license)
      case request.method
        when :get
          @user.reload # Make sure we have the latest version of the user

        when :post
          now = Time.now

          # Make sure password matches confirmation.
          if password = params['user']['password']
            if password == params['user']['password_confirmation']
              @user.change_password(password)
            else
              @user.errors.add(:password, :prefs_password_no_match.t)
            end
          end

          args = {}
          for type, arg in [
            [ :str,  :login ],
            [ :str,  :email ],
            [ :str,  :theme ],
            [ :str,  :locale ],
            [ :int,  :license_id ],
            [ :int,  :rows ],
            [ :int,  :columns ],
            [ :bool, :alternate_rows ],
            [ :bool, :alternate_columns ],
            [ :bool, :vertical_layout ],
            [ :bool, :email_comments_owner ],
            [ :bool, :email_comments_response ],
            [ :bool, :email_comments_all ],
            [ :bool, :email_observations_consensus ],
            [ :bool, :email_observations_naming ],
            [ :bool, :email_observations_all ],
            [ :bool, :email_names_author ],
            [ :bool, :email_names_editor ],
            [ :bool, :email_names_reviewer ],
            [ :bool, :email_names_all ],
            [ :bool, :email_locations_author ],
            [ :bool, :email_locations_editor ],
            [ :bool, :email_locations_all ],
            [ :bool, :email_general_feature ],
            [ :bool, :email_general_commercial ],
            [ :bool, :email_general_question ],
            [ :str,  :email_digest ],
            [ :bool, :email_html ],
          ]
            val = params[:user][arg]
            val = case type
              when :str  ; val.to_s
              when :int  ; val.to_i
              when :bool ; (val == '1' || val == 'checked')
            end
            if @user.send(arg) != val
              @user.send("#{arg}=", val)
              args["set_#{arg}"] = val
            end
          end

          # Only set 'modified' if exportable change happened.
          if !args.empty?
            @user.modified = now
            args[:id] = @user
          end

          if @user.errors.empty? && @user.save
            Transaction.put_user(args)
            flash_notice :prefs_success.t
            redirect_back_or_default(:action => "welcome")
          else
            flash_object_errors(@user)
          end
      end
    else
      store_location
      access_denied
    end
  end

  def profile
    if @user
      @licenses = License.current_names_and_ids(@user.license)
      if request.method == :get
        @user.reload # Make sure we have the latest version of the user
        @place_name      = @user.location ? @user.location.display_name : ""
        @copyright_holder = @user.legal_name
        @copyright_year    = Time.now.year
        @upload_license_id  = @user.license.id

      elsif request.method == :post
        now = Time.now
        args = {}
        for arg in [:name, :notes, :mailing_address]
          val = params[:user][arg].to_s
          if @user.send(arg) != val
            @user.send("#{arg}=", val)
            args["set_#{arg}"] = val
          end
        end

        # Make sure the given location exists before accepting it.
        @place_name = params['user']['place_name'].to_s
        if @place_name != ''
          location = Location.find_by_display_name(@place_name)
          if !location
            need_to_create_location = true
          elsif @user.location != location
            @user.location = location
            args["set_location"] = location
            @place_name = location.display_name
          end
        elsif @user.location
          @user.location = nil
          args["set_location"] = 0
        end

        # Check if we need to upload an image.
        upload = params['user']['upload_image']
        if upload && upload != ''
          name = upload.full_original_filename if upload.respond_to? :full_original_filename
          date = Time.local(params['date']['copyright_year'])
          image = Image.new(
            :image            => upload,
            :created          => now,
            :modified         => now,
            :user             => @user,
            :when             => date,
            :copyright_holder => params['copyright_holder'],
            :license_id       => params['upload']['license_id']
          )
          if !image.save
            flash_object_errors(image)
          elsif !image.save_image
            logger.error("Unable to upload image")
            flash_error :profile_invalid_image.
              t(:name => (name ? "'#{name}'" : '???'))
            flash_object_errors(image)
          else
            Transaction.post_image(
              :id               => image,
              :date             => date,
              :url              => image.original_url,
              :copyright_holder => params['copyright_holder'],
              :license_id       => params['upload']['license_id']
            )
            @user.image = image
            args[:set_image] = image
            flash_notice :profile_uploaded_image.
              t(:name => name ? "'#{name}'" : "##{image.id}")
          end
        end

        # Only set 'modified' if exportable change happened.
        if !args.empty?
          @user.modified = now
          args[:id] = @user
        end

        if @user.save
          Transaction.put_user(args)
          if need_to_create_location
            flash_notice :profile_must_define.t
            redirect_to(:controller => "location", :action => "create_location",
              :where => @place_name, :set_user => 1)
          else
            flash_notice :profile_success.t
            redirect_to(:controller => "observer", :action => "show_user", :id => @user.id)
          end
        else
          flash_object_errors(@user)
        end
      end
    else
      store_location
      access_denied
    end
  end

  def destroy_user
    if is_in_admin_mode?
      id = params['id']
      if id.to_s != ''
        user = User.find(id)
        if user.destroy
          Transaction.delete_user(:id => user)
        end
      end
    end
    redirect_back_or_default(:action => "welcome")
  end

  def logout_user
    if @user
      Transaction.logout_user(:id => @user)
      @user = set_session_user(nil)
      clear_autologin_cookie
    end
  end

  def welcome
  end

  def reverify
  end

  def verify
    id        = params['id']
    auth_code = params['auth_code']
    if id &&
       (user = User.find(id)) &&
       (auth_code == user.auth_code)

      # If not already verified, mark account "verified" and log user in.
      if user.verified
        @user = user
        @user.last_login = now = Time.now
        @user.verified   = now
        @user.save
        set_session_user(@user)
        Transaction.put_user(
          :id         => @user,
          :set_verify => @user.verified
        )

      # If already logged in, just send to "welcome" page.
      elsif @user
        redirect_to(:action => :welcome)

      # Otherwise send to login page, saying "you're already verified, dumb-ass".
      # (If someone grabs a user's verify email, they could theoretically use
      # it to log in any time they wanted to.  This makes it a one-time use.)
      else
        flash_warning(:reverify_already_verified.t)
        redirect_to(:action => :login)
      end

    else
      render(:action => "reverify")
    end
  end

  def remove_image
    if @user && @user.image
      @user.image = nil
      @user.save
      Transaction.put_user(
        :id        => @user,
        :set_image => 0
      )
      flash_notice :profile_removed_image.t
    end
    redirect_to(:controller => "observer", :action => "show_user", :id => @user.id)
  end

  def no_email_comments_owner;          no_email('comments_owner');          end
  def no_email_comments_response;       no_email('comments_response');       end
  def no_email_comments_all;            no_email('comments_all');            end
  def no_email_observations_consensus;  no_email('observations_consensus');  end
  def no_email_observations_naming;     no_email('observations_naming');     end
  def no_email_observations_all;        no_email('observations_all');        end
  def no_email_names_author;            no_email('names_author');            end
  def no_email_names_editor;            no_email('names_editor');            end
  def no_email_names_reviewer;          no_email('names_reviewer');          end
  def no_email_names_all;               no_email('names_all');               end
  def no_email_locations_author;        no_email('locations_author');        end
  def no_email_locations_editor;        no_email('locations_editor');        end
  def no_email_locations_all;           no_email('locations_all');           end
  def no_email_general_feature;         no_email('general_feature');         end
  def no_email_general_commercial;      no_email('general_commercial');      end
  def no_email_general_question;        no_email('general_question');        end

  # These are the old email flags, renamed in favor of more consistent ones.
  alias_method :no_comment_email,          :no_email_comments_owner
  alias_method :no_comment_response_email, :no_email_comments_response
  alias_method :no_commercial_email,       :no_email_general_commercial
  alias_method :no_consensus_change_email, :no_email_observations_consensus
  alias_method :no_feature_email,          :no_email_general_feature
  alias_method :no_name_change_email,      :no_email_names_author
  alias_method :no_name_proposal_email,    :no_email_observations_naming
  alias_method :no_question_email,         :no_email_general_question

  def no_email(type)
    if check_permission!(params[:id])
      method  = "email_#{type}="
      prefix  = "no_email_#{type}"
      success = "#{prefix}_success".to_sym
      @note   = "#{prefix}_note".to_sym
      set_val = "set_#{type}".to_sym
      @user.send(method, false)
      if @user.save
        Transaction.put_user(
          :id     => @user,
          set_val => false
        )
        flash_notice(success.t(:name => @user.unique_text_name))
        render(:action => :no_email)
      else
        # Probably should write a better error message here...
        flash_object_errors(@user)
        redirect_to(:controller => :observer, :action => :list_rss_logs)
      end
    else
      redirect_to(:controller => :observer, :action => :list_rss_logs)
    end
  end

  # Where are these used??  They can never work.  The session user
  # should never be set if the user isn't already verified!
  # def test_verify
  #   email = AccountMailer.create_verify(get_session_user)
  #   render(:text => "<pre>" + email.encoded + "</pre>")
  # end
  #
  # def send_verify
  #   AccountMailer.deliver_verify(get_session_user)
  #   flash_notice :reverify_sent.t
  #   redirect_back_or_default(:action => "welcome")
  # end

  def turn_admin_on
    if @user && @user.admin && !is_in_admin_mode?
      session[:admin] = true
    end
    redirect_back_or_default(:action => :welcome)
  end

  def turn_admin_off
    session[:admin] = nil
    redirect_back_or_default(:action => :welcome)
  end

  def show_alert
    if !@user
      redirect_back_or_default(:action => :welcome)
    elsif !@user.alert || !@user.alert_type
      flash_warning :user_alert_missing.t
      redirect_back_or_default(:action => :welcome)
    elsif request.method == :get
      @back = session['return-to']
      # render alert
    elsif request.method == :post
      if params[:commit] == :user_alert_okay.l
        @user.alert = nil
        @user.save
      else
        @user.alert_next_showing = Time.now + 1.day
        @user.save
      end
      if params[:back].to_s != ''
        redirect_to params[:back]
      else
        redirect_to '/'
      end
    end
  end

  def create_alert
    redirect = true
    id = params[:id]
    @user2 = User.find(id)
    if is_in_admin_mode?
      if request.method == :get
        # render form
        redirect = false
      elsif request.method == :post
        if params[:commit] == :user_alert_save.l
          @user2.alert_type  = params[:user2][:alert_type]
          @user2.alert_notes = params[:user2][:alert_notes]
          if params[:user2][:alert_type].to_s == ''
            flash_error :user_alert_missing_type.t
            @user2.errors.add(:alert_type)
            redirect = false
          else
            @user2.alert_created      = now = Time.now
            @user2.alert_next_showing = now
            @user2.alert_user_id      = @user.id
            @user2.save
            flash_notice :user_alert_saved.t(:user => @user2.login)
          end
        else
          @user2.alert = nil
          @user2.save
          flash_notice :user_alert_deleted.t(:user => @user2.login)
        end
      end
    end
    if redirect
      redirect_to(:controller => :observer, :action => :show_user, :id => id)
    end
  end

  def add_user_to_group
    redirect = true
    if is_in_admin_mode?
      if request.method == :post
        user_name  = params['user_name'].to_s
        group_name = params['group_name'].to_s
        user       = User.find_by_login(user_name)
        group      = UserGroup.find_by_name(group_name)
        flash_error :add_user_to_group_no_user.t(:user => user_name)    if !user
        flash_error :add_user_to_group_no_group.t(:group => group_name) if !group
        if user && group
          if user.user_groups.member?(group)
            flash_warning :add_user_to_group_already. \
              t(:user => user_name, :group => group_name)
          else
            user.user_groups << group
            Transaction.put_user_group(
              :id       => group,
              :add_user => user
            )
            flash_notice :add_user_to_group_success. \
              t(:user => user_name, :group => group_name)
          end
        end
      else
        redirect = false
      end
    else
      flash_error :app_permission_denied.t
    end
    if redirect
      redirect_back_or_default(:controller => 'observer', :action => 'index')
    end
  end

  # This is used to test the flash error mechanism in the unit tests.
  def test_flash
    notice   = params[:notice]
    warning  = params[:warning]
    error    = params[:error]
    redirect = params[:redirect]
    flash_notice(notice)   if notice
    flash_warning(warning) if warning
    flash_error(error)     if error
    if redirect
      redirect_to(redirect)
    else
      render(:text => '', :layout => true)
    end
  end
end
