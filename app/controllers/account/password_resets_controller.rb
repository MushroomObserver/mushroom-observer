# frozen_string_literal: true

module Account
  # "I forgot my password, email me a new one" flow. Extracted out of
  # LoginController (which used to bolt this on as email_new_password/
  # new_password_request) into its own RESTful new/create pair.
  class PasswordResetsController < ApplicationController
    def new
      @new_user = User.new
      render_new_view
    end

    def create
      @login = params[:new_user] && params[:new_user][:login]
      @new_user = find_user_by_login_name_or_email(@login)
      if @new_user.nil?
        flash_error(:runtime_email_new_password_failed.t(user: @login))
        return render_new_view_invalid
      end

      set_random_password_for_new_user_and_email_them
    end

    private

    def find_user_by_login_name_or_email(login)
      return nil if login.blank?

      User.find_by(
        User[:login].eq(login).
        or(User[:name].eq(login)).
        or(User[:email].eq(login))
      )
    end

    def render_new_view(status: :ok, **render_opts)
      render(Views::Controllers::Account::PasswordResets::New.new(
               new_user: @new_user
             ), status: status, **render_opts)
    end

    def set_random_password_for_new_user_and_email_them
      password = String.random(10)
      # `change_password` persists immediately via `update_attribute`
      # (bypassing validations) and returns that save's result -- a
      # separate `@new_user.save` afterward would be redundant, and
      # worse, misleading: it can't undo a password change that
      # already landed, so checking it as the success signal risks
      # flashing an error (no redirect, no email) after the password
      # was already silently changed underneath the user.
      if @new_user.change_password(password)
        flash_notice(:runtime_email_new_password_success.tp +
                     :email_spam_notice.tp)
        # Migrated from QueuedEmail::Password to ActionMailer + ActiveJob.
        # See .claude/deliver_later_migration_plan.md for details.
        PasswordMailer.build(receiver: @new_user, password:).deliver_later
        redirect_to(new_account_login_path)
      else
        flash_object_errors(@new_user)
        render_new_view_invalid
      end
    end
  end
end
