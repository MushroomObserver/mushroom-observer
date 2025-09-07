# frozen_string_literal: true

class UserManagementService::MultipleUserHandler
  attr_reader :input_handler, :output_handler

  def initialize(input_handler:, output_handler:)
    @input_handler = input_handler
    @output_handler = output_handler
  end

  def handle_users(users, email)
    display_multiple_users_header(users, email)
    display_multiple_users_list(users)
    display_verify_all_option(users)

    handle_user_selection(users)
  end

  private

  def display_multiple_users_header(_users, email)
    output_handler.puts("Multiple users found with email '#{email}':")
    output_handler.puts("")
  end

  def display_multiple_users_list(users)
    users.each_with_index do |user, index|
      status = format_verification_status(user)
      output_handler.puts("#{index + 1}. #{user.login} (#{user.name}) " \
                          "- #{status}")
    end
  end

  def display_verify_all_option(users)
    output_handler.puts("#{users.count + 1}. Verify all users")
    output_handler.puts("")
  end

  def format_verification_status(user)
    if user.verified?
      timestamp = user.verified.strftime("%Y-%m-%d %H:%M:%S")
      "✓ Verified at #{timestamp}"
    else
      "✗ Not verified"
    end
  end

  def handle_user_selection(users)
    loop do
      choice = get_user_choice(users)

      return false if quit_requested?(choice)

      choice_num = choice.to_i

      return verify_all_users?(users) if verify_all_selected?(choice_num, users)
      return verify_selected_user?(users[choice_num - 1]) if valid_selection?(
        choice_num, users
      )

      display_invalid_choice_message(users)
    end
  end

  def get_user_choice(users)
    prompt = "Select user to verify (1-#{users.count + 1}) or 'q' to quit: "
    input_handler.get_input(prompt)
  end

  def quit_requested?(choice)
    quit_choice = %w[q quit].include?(choice.downcase)
    output_handler.puts("Operation cancelled.") if quit_choice
    quit_choice
  end

  def verify_all_selected?(choice_num, users)
    choice_num == users.count + 1
  end

  def valid_selection?(choice_num, users)
    choice_num.between?(1, users.count)
  end

  def display_invalid_choice_message(users)
    message = "Invalid choice. Please enter a number between 1 and " \
              "#{users.count + 1}, or 'q' to quit."
    output_handler.puts(message)
  end

  def verify_all_users?(users)
    verified_count = count_and_verify_unverified_users(users)
    display_verification_summary(verified_count)
    true
  end

  def count_and_verify_unverified_users(users)
    verified_count = 0
    verification_time = Time.current

    users.each do |user|
      next if user.verified?

      user.update!(verified: verification_time)
      verified_count += 1
      output_handler.puts("Verified: #{user.login} at #{verification_time}")
    end

    verified_count
  end

  def display_verification_summary(verified_count)
    if verified_count.positive?
      output_handler.puts("Successfully verified #{verified_count} user(s).")
    else
      output_handler.puts("All users were already verified.")
    end
  end

  def verify_selected_user?(user)
    if user.verified?
      display_already_verified_message(user, user.login)
    else
      perform_verification(user, user.login)
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
end
