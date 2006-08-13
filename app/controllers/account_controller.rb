class AccountController < ApplicationController
  model   :user

  def login
    case @request.method
      when :post
        user = User.authenticate(@params['user_login'], @params['user_password'])
        if @session['user'] = user

          flash[:notice]  = "Login successful"
          user.last_login = Time.now
          user.save
          redirect_back_or_default :action => "welcome"
        else
          @login    = @params['user_login']
          @message  = "Login unsuccessful"
      end
    end
  end
  
  def signup
    case @request.method
      when :post
        @user = User.new(@params['user'])
        @user.created = Time.now
        @user.last_login = @user.created
        if @user.save      
          @session['user'] = User.authenticate(@user.login, @params['user']['password'])
          flash[:notice]  = "Signup successful"
          AccountMailer.deliver_verify(@user)
          redirect_back_or_default :action => "welcome"          
        end
      when :get
        @user = User.new
    end      
  end  
  
  def prefs
    @user = @session['user']
    case @request.method
      when :post
        @user.change_email(@params['user']['email'])
        @user.change_name(@params['user']['name'])
        @user.change_theme(@params['user']['theme'])
        password = @params['user']['password']
        error = false
        if password
          if password == @params['user']['password_confirmation']
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
    if @params['id']
      @user = User.find(@params['id'])
      @user.destroy
    end
    redirect_back_or_default :action => "welcome"
  end  
    
  def logout
    @session['user'] = nil
  end
    
  def welcome
  end
  
  def reverify
  end
  
  def verify
    if @params['id']
      @user = User.find(@params['id'])
      @user.verified = Time.now
      @user.save
      if @session['user'].id == @user.id
        @session['user'].verified = Time.now
      end
    else
      render :action => "reverify"
    end
  end
  
  def test_verify
    user = @session['user']
    email = AccountMailer.create_verify(user)
    render(:text => "<pre>" + email.encoded + "</pre>")
  end
  
  def send_verify
    AccountMailer.deliver_verify(@session['user'])
    redirect_back_or_default :action => "welcome"
  end
end
