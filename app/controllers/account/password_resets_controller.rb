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
      @new_user = User.where("login = ? OR name = ? OR email = ?",
                             @login, @login, @login).first
      if @new_user.nil?
        flash_error(:runtime_email_new_password_failed.t(user: @login))
        return render_new_view_invalid
      end

      set_random_password_for_new_user_and_email_them
    end

    private

    def render_new_view(status: :ok, **render_opts)
      render(Views::Controllers::Account::PasswordResets::New.new(
               new_user: @new_user
             ), status: status, **render_opts)
    end

    def set_random_password_for_new_user_and_email_them
      password = String.random(10)
      @new_user.change_password(password)
      if @new_user.save
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
