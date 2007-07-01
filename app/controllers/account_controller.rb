class AccountController < ApplicationController
  # model   :user

  def login
    case request.method
      when :post
        user = User.authenticate(params['user_login'], params['user_password'])
        if session['user'] = user
          logger.warn("%s, %s, %s" % [user.login, params['user_login'], params['user_password']])
          flash[:notice]  = "Login successful"
          user.last_login = Time.now
          user.save
          redirect_back_or_default :action => "welcome"
        else
          @login    = params['user_login']
          @message  = "Login unsuccessful"
      end
    end
  end
  
  def signup
    case request.method
      when :post
        theme = params['user']['theme']
        login = params['user']['login']
        valid_themes = CSS + ["NULL"]
        if valid_themes.member?(theme) and (login != 'test_denied')
          @user = User.new(params['user'])
          @user.created = Time.now
          @user.last_login = @user.created
          @user.change_rows(5)
          @user.change_columns(3)
          if @user.save      
            session['user'] = User.authenticate(@user.login, params['user']['password'])
            flash[:notice]  = "Signup successful.  Verification sent to your email account."
            AccountMailer.deliver_verify(@user)
            redirect_back_or_default :action => "welcome"          
          end
        else
          AccountMailer.deliver_denied(params['user'])
          redirect_back_or_default :action => "welcome"          
        end
      when :get
        @user = User.new
    end      
  end  
  
  def email_new_password
    case request.method
      when :post
        login = params['user']['login']
        @user = User.find(:first, :conditions => ["login = ?", login])
        if @user.nil?
          flash[:notice] = sprintf("Unable to find the user, %s.", login)
        else
          password = random_password(10)
          @user.change_password(password)
          if @user.save      
            session['user'] = User.authenticate(@user.login, params['user']['password'])
            flash[:notice]  = "Password successfully changed.  New password has been sent to your email account."
            AccountMailer.deliver_new_password(@user, password)
          end
        end
        render :action => "login"          
      when :get
        @user = User.new
    end      
  end  
  
  def prefs
    @user = session['user']
    case request.method
      when :post
        @user.change_email(params['user']['email'])
        @user.change_name(params['user']['name'])
        @user.feature_email = params['user']['feature_email']
        @user.commercial_email = params['user']['commercial_email']
        @user.question_email = params['user']['question_email']
        @user.change_theme(params['user']['theme'])
        @user.change_rows(params['user']['rows'])
        @user.change_columns(params['user']['columns'])
        @user.alternate_rows = params['user']['alternate_rows']
        @user.alternate_columns = params['user']['alternate_columns']
        @user.vertical_layout = params['user']['vertical_layout']
        password = params['user']['password']
        error = false
        if password
          if password == params['user']['password_confirmation']
            @user.change_password(password)
          else
            error = true
            flash[:notice] = "Password and confirmation did not match"
            render :action => "prefs"
          end
        end
        unless error
          if @user.save      
            flash[:notice]  = "Preferences updated"
            redirect_back_or_default :action => "welcome"
          end
        end
    end      
  end  
  
  def delete
    if params['id']
      @user = User.find(params['id'])
      @user.destroy
    end
    redirect_back_or_default :action => "welcome"
  end  
    
  def logout_user
    session['user'] = nil
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
      if session['user'].id == @user.id
        session['user'].verified = Time.now
      end
    else
      render :action => "reverify"
    end
  end
  
  def no_feature_email
    if login_check params['id']
      @user.feature_email = false
      if @user.save
        flash[:notice] = "Automated feature email disabled for " + @user.unique_text_name
      end
      user = session['user']
      session['user'].feature_email = false
    end
  end
  
  def no_question_email
    if login_check params['id']
      @user.question_email = false
      if @user.save
        flash[:notice] = "Question email disabled for " + @user.unique_text_name
      end
      user = session['user']
      session['user'].question_email = false
    end
  end
  
  def no_commercial_email
    if login_check params['id']
      @user.commercial_email = false
      if @user.save
        flash[:notice] = "Commercial email inquiries disabled for " + @user.unique_text_name
      end
      user = session['user']
      session['user'].commercial_email = false
    end
  end
  
  def test_verify
    user = session['user']
    email = AccountMailer.create_verify(user)
    render(:text => "<pre>" + email.encoded + "</pre>")
  end
  
  def send_verify
    AccountMailer.deliver_verify(session['user'])
    flash[:notice] = "Verification sent to your email account."
    redirect_back_or_default :action => "welcome"
  end
  
  protected
  
  # Make sure the given user is the one that's logged in.  If no one is logged in
  # then give them a chance to login.
  def login_check(id)
    result = !session['user'].nil?
    if result
      # Undo the store_location
      session['return-to'] = url_for :controller => 'observer', :action => 'index'
      if id
        @user = User.find(id)
        if @user != session['user']
          flash[:notice] = "Permission denied"
          result = false
        end
      else
        redirect_to :action => 'prefs'
        result = false
      end
    else
      store_location
      redirect_to :action => 'login'
    end
    result
  end
  
end
