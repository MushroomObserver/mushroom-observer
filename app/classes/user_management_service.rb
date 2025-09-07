# frozen_string_literal: true

# app/services/user_management_service.rb

class UserManagementService
  attr_reader :input_handler, :output_handler

  def initialize(input_handler: StdinInputHandler.new,
                 output_handler: StdoutOutputHandler.new)
    @input_handler = input_handler
    @output_handler = output_handler
  end

  def create_or_update_user?
    output_handler.print_header("User Creation/Update Tool")

    user_params = collect_user_params
    return false unless user_params

    create_new_user?(user_params)
  end

  def list_users
    users = User.order(:login)

    if users.empty?
      output_handler.puts("No users found.")
      return
    end

    display_user_list_header
    users.each { |user| display_user_row(user) }
  end

  def verify_user?
    output_handler.print_header("User Verification Tool")

    identifier = input_handler.get_input("Enter login or email: ")
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
    login = input_handler.get_input("Enter login: ")
    return validation_error?("Login cannot be blank") if login.blank?
    return validation_error?("Login in use") if User.find_by(login:)

    login
  end

  def collect_name
    name = input_handler.get_input("Enter full name: ")

    name
  end

  def collect_email
    email = input_handler.get_input("Enter email: ")
    return validation_error?("Email cannot be blank") if email.blank?
    return validation_error?("Invalid email format") unless valid_email?(email)

    email
  end

  def collect_passwords
    password = input_handler.get_password("Enter password: ")
    return validation_error?("Password cannot be blank") if password.blank?

    confirmation = input_handler.get_password("Confirm password: ")
    if password != confirmation
      return validation_error?("Passwords do not match")
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
      display_user_success(user, "created")
      true
    else
      display_user_errors(user, "creating")
      false
    end
  end

  def display_user_success(user, action)
    output_handler.puts("User '#{user.login}' #{action} successfully!")
    output_handler.puts("  Name: #{user.name}")
    output_handler.puts("  Email: #{user.email}")
    output_handler.puts("  Verified: #{user.verified}")
  end

  def display_user_errors(user, action)
    output_handler.puts("Error #{action} user:")
    user.errors.full_messages.each do |error|
      output_handler.puts("  - #{error}")
    end
  end

  def display_user_list_header
    output_handler.puts("=== Users ===")
    output_handler.printf("%-20s %-30s %-30s %-25s\n",
                          "Login", "Name", "Email", "Verified")
    output_handler.puts("-" * 107)
  end

  def display_user_row(user)
    verified_display = if user.verified?
                         user.verified.strftime("%Y-%m-%d %H:%M:%S")
                       else
                         "No"
                       end
    output_handler.printf("%-20s %-30s %-30s %-25s\n",
                          user.login,
                          user.name[0..29],
                          user.email[0..29],
                          verified_display)
  end

  def verify_by_email?(email)
    users = User.where(email: email)

    if users.empty?
      output_handler.puts("No users found with email '#{email}'")
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
      output_handler.puts("User with login '#{login}' not found.")
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

  def display_already_verified_message(user, identifier)
    timestamp = user.verified.strftime("%Y-%m-%d %H:%M:%S")
    output_handler.puts("User '#{identifier}' is already verified " \
                        "(#{timestamp}).")
  end

  def perform_verification(user, identifier)
    verification_time = Time.current
    user.update!(verified: verification_time)
    output_handler.puts("User '#{identifier}' has been verified at " \
                        "#{verification_time}.")
  end

  def verify_single_user?(user, _identifier)
    verification_time = Time.current
    user.update!(verified: verification_time)
    message = "User '#{user.login}' (#{user.email}) has been verified at " \
              "#{verification_time}."
    output_handler.puts(message)
    true
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
    output_handler.puts("Error: #{message}")
    false
  end
end
