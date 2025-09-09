# frozen_string_literal: true

# app/services/user_management_service.rb

class UserManagementService
  attr_reader :input_handler, :output_handler

  def initialize(input_handler: StdinInputHandler.new,
                 output_handler: StdoutOutputHandler.new)
    @input_handler = input_handler
    @output_handler = output_handler
  end

  def create_user?
    output_handler.print_header(:user_add_tool.t)

    user_params = collect_user_params
    return false unless user_params

    create_new_user?(user_params)
  end

  def verify_user?
    output_handler.print_header(:user_verify_tool.t)

    identifier = input_handler.get_input(:user_verify_prompt.t)
    return false if identifier.blank?

    if email_identifier?(identifier)
      verify_by_email?(identifier)
    else
      verify_by_login?(identifier)
    end
  end

  private

  def collect_user_params
    login = collect_login
    return false unless login

    name = collect_name
    return false unless name

    email = collect_email
    return false unless email

    passwords = collect_passwords
    return false unless passwords

    build_user_params(login, name, email, passwords)
  end

  def collect_login
    login = input_handler.get_input(:user_add_login_prompt.t)
    return validation_error?(:user_add_login_not_blank.t) if login.blank?
    return validation_error?(:user_add_login_in_use.t) if User.find_by(login:)

    login
  end

  def collect_name
    input_handler.get_input(:user_add_name_prompt.t)
  end

  def collect_email
    email = input_handler.get_input(:user_add_email_prompt.t)
    return validation_error?(:user_add_email_not_blank.t) if email.blank?
    unless valid_email?(email)
      return validation_error?(:user_add_email_invalid.t)
    end

    email
  end

  def collect_passwords
    password = input_handler.get_password(:user_add_password_prompt.t)
    return validation_error?(:user_add_password_not_blank.t) if password.blank?

    confirmation = input_handler.get_password(
      :user_add_password_confirm_prompt.t
    )
    if password != confirmation
      return validation_error?(:user_add_password_no_match.t)
    end

    { password: password, password_confirmation: confirmation }
  end

  def build_user_params(login, name, email, passwords)
    {
      login: login,
      name: name,
      email: email,
      password: passwords[:password],
      password_confirmation: passwords[:password_confirmation]
    }
  end

  def create_new_user?(user_params)
    user = User.new(user_params.merge(verified: Time.current))

    if user.save
      display_user_success(user)
      true
    else
      display_user_errors(user)
      false
    end
  end

  def display_user_success(user)
    output_handler.puts(:user_add_success.t(login: user.login).unescape_html)
    output_handler.puts("  #{:NAME.t}: #{user.name}")
    output_handler.puts("  #{:EMAIL.t}: #{user.email}")
    output_handler.puts("  #{:user_add_verified.t}: #{user.verified}")
  end

  def display_user_errors(user)
    output_handler.puts(:user_add_error_header.t)
    user.errors.full_messages.each do |error|
      output_handler.puts("  - #{error}")
    end
  end

  def verify_by_email?(email)
    users = User.where(email: email).order(:login)

    if users.empty?
      output_handler.puts(:user_verify_email_missing.t(email:).unescape_html)
      false
    elsif single_user?(users)
      verify_single_user?(users.first, email)
    else
      MultipleUserHandler.new(
        input_handler: input_handler,
        output_handler: output_handler
      ).handle_users(users, email)
    end
  end

  def verify_by_login?(login)
    user = User.find_by(login: login)

    unless user
      output_handler.puts(:user_verify_login_missing.t(login:).unescape_html)
      return false
    end

    verify_user_by_login?(user, login)
  end

  def verify_user_by_login?(user, login)
    if user.verified?
      display_already_verified_message(user, login)
    else
      perform_verification(user, login)
    end
    true
  end

  def display_already_verified_message(user, login)
    timestamp = user.verified.strftime("%Y-%m-%d %H:%M:%S")
    output_handler.puts(:user_verify_already_verified.t(
      login:, timestamp:
    ).unescape_html)
  end

  def perform_verification(user, login)
    timestamp = Time.current
    user.update!(verified: timestamp)
    output_handler.puts(:user_verify_verified.t(login:,
                                                timestamp:).unescape_html)
  end

  def verify_single_user?(user, _identifier)
    verify_user_by_login?(user, user.login)
  end

  def email_identifier?(identifier)
    identifier.include?("@")
  end

  def single_user?(users)
    users.one?
  end

  def valid_email?(email)
    email.match?(/\A[\w+\-.]+@[a-z\d-]+(\.[a-z\d-]+)*\.[a-z]+\z/i)
  end

  def validation_error?(message)
    output_handler.puts("#{:user_add_error.t}: #{message}")
    false
  end
end
