#
#  Views: ("*" - login required, "R" - root required))
#     signup
#     welcome
#
#     verify
#     reverify
#     send_verify
#
#     login
#     logout_user
#     email_new_password
#
#   * prefs
#   * profile
#   * remove_image
#
#   * no_email_xxx      Callbacks from email to turn off various types of email.
#
#  Admin Tools:
#   R delete
#
#  Test Views:
#     test_verify
#
#  Helpers:
#    hide_params(obj, out, prefix)
#    login_check(id)
#
################################################################################

class AccountController < ApplicationController
  before_filter :login_required, :except => [
    :signup,
    :welcome,
    :verify,
    :reverify,
    :send_verify,
    :login,
    :logout_user,
    :email_new_password
  ]

  def login
    case request.method
      when :get
        @login = ""
        @remember = true
      when :post
        login = params['user_login']
        password = params['user_password']
        user = User.authenticate(login, password)
        user = User.authenticate(login, password.strip) if !user
        @remember = params['user'] && params['user']['remember_me'] == "1"
        if set_session_user(user)
          logger.warn("%s, %s, %s" % [user.login, params['user_login'], params['user_password']])
          flash_notice :login_success.t
          user.last_login = Time.now
          user.save
          if @remember
            set_autologin_cookie(user)
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
  # flash[:params].  I store them in the login page as hidden fields.
  # When user logs in, it puts these params back into flash[:params]
  # and redirects to the original page.  The login_required "before"
  # filter will then merge them back into params[] automatically.
  # This method flattens the params structure into a simple array.
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
    case request.method
      when :get
        @new_user = User.new
      when :post
        theme = params['new_user']['theme']
        login = params['new_user']['login']
        valid_themes = CSS + ["NULL"]
        if valid_themes.member?(theme) and (login != 'test_denied')
          @new_user = User.new(params['new_user'])
          @new_user.created = Time.now
          @new_user.last_login = @new_user.created
          @new_user.rows = 5
          @new_user.columns = 3
          @new_user.mailing_address = ''
          @new_user.notes = ''
          if @new_user.save
            user = User.authenticate(@new_user.login, params['new_user']['password'])
            set_session_user(user)
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
    case request.method
      when :get
        @new_user = User.new
      when :post
        @login = params['new_user']['login']
        @new_user = User.find(:first, :conditions => [ "login = ? OR name = ? OR email = ?",
                                                       @login, @login, @login ])
        if @new_user.nil?
          flash_error :email_new_password_failed.t(:user => @login)
        else
          password = random_password(10)
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
          error = false

          @user.login             = params['user']['login']
          @user.email             = params['user']['email']
          @user.theme             = params['user']['theme']
          @user.locale            = params['user']['locale'].to_s
          @user.license_id        = params['user']['license_id'].to_i
          @user.rows              = params['user']['rows']
          @user.columns           = params['user']['columns']
          @user.alternate_rows    = params['user']['alternate_rows']
          @user.alternate_columns = params['user']['alternate_columns']
          @user.vertical_layout   = params['user']['vertical_layout']

          @user.email_comments_owner         = params['user']['email_comments_owner']
          @user.email_comments_response      = params['user']['email_comments_response']
          @user.email_comments_all           = params['user']['email_comments_all']
          @user.email_observations_consensus = params['user']['email_observations_consensus']
          @user.email_observations_naming    = params['user']['email_observations_naming']
          @user.email_observations_all       = params['user']['email_observations_all']
          @user.email_names_author           = params['user']['email_names_author']
          @user.email_names_editor           = params['user']['email_names_editor']
          @user.email_names_reviewer         = params['user']['email_names_reviewer']
          @user.email_names_all              = params['user']['email_names_all']
          @user.email_locations_author       = params['user']['email_locations_author']
          @user.email_locations_editor       = params['user']['email_locations_editor']
          @user.email_locations_all          = params['user']['email_locations_all']
          @user.email_general_feature        = params['user']['email_general_feature']
          @user.email_general_commercial     = params['user']['email_general_commercial']
          @user.email_general_question       = params['user']['email_general_question']
          # @user.email_digest                 = params['user']['email_digest']
          @user.email_html                   = params['user']['email_html']

          password = params['user']['password']
          if password
            if password == params['user']['password_confirmation']
              @user.change_password(password)
            else
              error = true
              flash_error :prefs_password_no_match.t
            end
          end

          if error
          elsif !@user.save
            flash_object_errors(@user)
          else
            flash_notice :prefs_success.t
            redirect_back_or_default(:action => "welcome")
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
      case request.method
        when :get
          @user.reload # Make sure we have the latest version of the user
          @place_name      = @user.location ? @user.location.display_name : ""
          @copyright_holder = @user.legal_name
          @copyright_year    = Time.now.year
          @upload_license_id  = @user.license.id

        when :post
          error = false

          @user.name            = params['user']['name']
          @user.notes           = params['user']['notes']
          @user.mailing_address = params['user']['mailing_address']
          @copyright_holder     = params['copyright_holder']
          @copyright_year       = params['date']['copyright_year'] if params['date']
          @upload_license_id    = params['upload']['license_id']   if params['upload']

          @place_name = params['user']['place_name']
          if @place_name && @place_name != ""
            if location = Location.find_by_display_name(@place_name)
              @user.location = location
              @place_name = location.display_name
            else
              need_to_create_location = true
            end
          else
            @user.location = nil
          end

          upload = params['user']['upload_image']
          if upload && upload != ""
            name = upload.full_original_filename if upload.respond_to? :full_original_filename
            now = Time.now
            image = Image.new(
              :image    => upload,
              :created  => now,
              :modified => now,
              :user     => @user,
              :title    => @user.legal_name,
              :when     => Time.local(@copyright_year),
              :copyright_holder => @copyright_holder,
              :license_id  => @upload_license_id
            )
            if !image.save
              flash_object_errors(image)
            elsif !image.save_image
              logger.error("Unable to upload image")
              flash_error :profile_invalid_image. \
                t(:name => (name ? "'#{name}'" : '???'))
            else
              @user.image = image
              flash_notice :profile_uploaded_image. \
                t(:name => name ? "'#{name}'" : "##{image.id}")
            end
          end

          if error
          elsif !@user.save
            flash_object_errors(@user)
          elsif need_to_create_location
            flash_notice :profile_must_define.t
            redirect_to(:controller => "location", :action => "create_location",
              :where => @place_name, :set_user => 1)
          else
            flash_notice :profile_success.t
            redirect_to(:controller => "observer", :action => "show_user", :id => @user.id)
          end
      end
    else
      store_location
      access_denied
    end
  end

  def delete
    if check_permission(0)
      if params['id']
        @user = User.find(params['id'])
        @user.destroy
      end
    end
    redirect_back_or_default(:action => "welcome")
  end

  def logout_user
    @user = set_session_user(nil)
    clear_autologin_cookie
  end

  def welcome
  end

  def reverify
  end

  def verify
    if params['id']
      @user = User.find(params['id'])
      @user.verified = Time.now
      @user.save
    else
      render(:action => "reverify")
    end
  end

  def remove_image
    if @user && @user.image
      @user.image = nil
      @user.save
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
    if login_check params['id']
      method  = "email_#{type}="
      prefix  = "no_email_#{type}"
      success = "#{prefix}_success".to_sym
      @note   = "#{prefix}_note".to_sym
      @user.send(method, false)
      if @user.save
        flash_notice(success.t(:name => @user.unique_text_name))
        render(:action => :no_email)
      else
        # Probably should write a better error message here...
        flash_error('Sorry, something went wrong...')
        redirect_to(:controller => :observer, :action => :list_rss_logs)
      end
    else
      flash_error(:app_permission_denied.t)
      redirect_to(:controller => :observer, :action => :list_rss_logs)
    end
  end

  def test_verify
    @user = get_session_user
    email = AccountMailer.create_verify(@user)
    render(:text => "<pre>" + email.encoded + "</pre>")
  end

  def send_verify
    AccountMailer.deliver_verify(get_session_user)
    flash_notice :reverify_sent.t
    redirect_back_or_default(:action => "welcome")
  end

  def add_user_to_group
    redirect = true
    if session['user_id'].to_i == 0
      case request.method
        when :post
          user_name = params['user_name']
          user = User.find_by_login(user_name)
          if user
            group_name = params['group_name']
            user_group = UserGroup.find_by_name(group_name)
            if user_group
              if user.user_groups.member?(user_group)
                flash_warning :add_user_to_group_already. \
                  t(:user => user_name, :group => group_name)
              else
                user.user_groups << user_group
                if user.save
                  flash_notice :add_user_to_group_success. \
                    t(:user => user_name, :group => group_name)
                end
              end
            else
              flash_error :add_user_to_group_no_group.t(:group => group_name)
            end
          else
            flash_error :add_user_to_group_no_user.t(:user => user_name)
          end
        when :get
          redirect = false
      end
    else
      flash_error :app_permission_denied.t
    end
    if redirect
      redirect_back_or_default(:controller => 'observer', :action => 'index')
    end
  end

  protected

  # Make sure the given user is the one that's logged in.  If no one is logged in
  # then give them a chance to login.
  def login_check(id)
    result = !get_session_user.nil?
    if result
      # Undo the store_location
      session['return-to'] = url_for(:controller => 'observer', :action => 'index')
      if id
        user = User.find(id)
        if user != get_session_user
          flash_error :app_permission_denied.t
          result = false
        end
      else
        redirect_to(:action => 'prefs')
        result = false
      end
    else
      store_location
      access_denied
    end
    result
  end

end
