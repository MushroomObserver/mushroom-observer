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
      @new_user = find_user_by_login_or_email(@login)
      if @new_user.nil?
        flash_error(:runtime_email_new_password_failed.t(user: @login))
        return render_new_view_invalid
      end

      set_random_password_for_new_user_and_email_them
    end

    private

    # `users.name` is a display name, not an identifier: accounts carry
    # names that match other accounts' logins, and the lowest id among
    # the matches wins -- so matching it reset a stranger's password and
    # left the requester's own password in place.
    def find_user_by_login_or_email(login)
      return nil if login.blank?

      match = User[:login].eq(login).or(User[:email].eq(login))
      first = User.find_by(match)
      return first if first.nil? || [first.login, first.email].include?(login)

      # Both columns collate case- and trailing-space-insensitively, so
      # another account can match the same string. The spelling the
      # person typed wins.
      User.where(match).find { |user| user.login == login } || first
    end

    def render_new_view(status: :ok, **render_opts)
      render(Views::Controllers::Account::PasswordResets::New.new(
               new_user: @new_user
             ), status: status, **render_opts)
    end

    def set_random_password_for_new_user_and_email_them
      password = String.random(10)
      # `change_password` persists immediately, skipping validations,
      # and returns that save's result. A `@new_user.save` here could
      # not undo a change that already landed, so checking it instead
      # risks flashing an error after the password had changed.
      if @new_user.change_password(password)
        flash_notice(:runtime_email_new_password_success.tp +
                     :email_spam_notice.tp)
        # Migrated from QueuedEmail::Password to ActionMailer + ActiveJob.
        # See .claude/deliver_later_migration_plan.md for details.
        PasswordMailer.build(receiver: @new_user, password:).deliver_later
        # Read back by Account::LoginController#login_success, which
        # nudges them to replace the emailed password. Scoped to the
        # id, so requesting a reset for one account and logging into
        # another does not carry the nudge across.
        session[:password_emailed_to] = @new_user.id
        redirect_to(new_account_login_path)
      else
        flash_object_errors(@new_user)
        render_new_view_invalid
      end
    end
  end
end
