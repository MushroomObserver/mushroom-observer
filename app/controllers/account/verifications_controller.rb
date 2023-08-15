# frozen_string_literal: true

module Account
  class VerificationsController < ApplicationController
    before_action :login_required, except: [
      :new,
      :create,
      :reverify,
      :resend_email
    ]
    before_action :disable_link_prefetching, except: [
      :new,
      :create
    ]

    # Regular signup verifications hit this page only (via GET).
    def new
      id        = params[:id]
      auth_code = params[:auth_code]
      return unless (user = find_or_goto_index(User, id))

      # This will happen legitimately whenever a non-verified user tries to
      # login.  The user just gets redirected here instead of being properly
      # logged in.  "auth_code" will be missing.
      if auth_code != user.auth_code
        reverify_unverified_user(user)

      # If already logged in and verified, just send to "welcome" page.
      elsif @user == user
        redirect_to(account_welcome_path)

      # If user is already verified, send them back to the login page.  (If
      # someone grabs a user's verify email, they could theoretically use it to
      # log in any time they wanted to.  This makes it a one-time use.)
      elsif user.verified
        redirect_already_used_verification(user)

      # If not already verified, and the code checks out, then mark account
      # "verified", log user in, and display the "you're verified" page.
      else
        mark_user_verified_and_login(user)
        render(:new)
      end
    end

    # If user was created via API, we must ask the user to choose a password
    # first before we can verify them. The choose_password form is currently the
    # only place that should POST to this action, via account_verify_path
    def create
      id        = params[:id]
      auth_code = params[:auth_code]
      return unless (user = find_or_goto_index(User, id))

      if auth_code != user.auth_code
        reverify_unverified_user(user)
      elsif @user == user
        redirect_to(account_welcome_path)
      elsif user.verified
        redirect_already_used_verification(user)
      else
        mark_user_verified_and_login(user)
        render(action: :new)
      end
    end

    # This action is never actually used.  Its template is rendered by verify.
    def reverify
      raise("This action should never occur!")
    end

    # Route linked from the "reverify" template. Re-sends verification email.
    def resend_email
      return unless (user = find_or_goto_index(User, params[:id]))

      VerifyAccountMailer.build(user).deliver_now
      self.class.notify_root_of_verification_email(user)
      flash_notice(:runtime_reverify_sent.tp + :email_spam_notice.tp)
      redirect_back_or_default(account_welcome_path)
    end

    # This method is also called by AccountController, so it's a class method.
    def self.notify_root_of_verification_email(user)
      url = "#{MO.http_domain}/account/verify/#{user.id}?" \
            "auth_code=#{user.auth_code}"
      content = :email_verify_intro.tp(user: user.login, link: url)
      WebmasterMailer.build(
        sender_email: user.email,
        subject: :email_subject_verify.l,
        content: "email: #{user.email}\n\n #{content.html_to_ascii}"
      ).deliver_now
    end

    private

    def reverify_unverified_user(user)
      @unverified_user = user
      render(action: :reverify)
    end

    def redirect_already_used_verification(_user)
      flash_warning(:runtime_reverify_already_verified.t)
      @user = nil
      User.current = nil
      session_user_set(nil)
      redirect_to(new_account_login_path)
    end

    def mark_user_verified_and_login(user)
      @user = user
      User.current = user
      session_user_set(user)
      @user.verify
    end
  end
end
