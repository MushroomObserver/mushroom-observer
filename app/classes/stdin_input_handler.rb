# frozen_string_literal: true

# app/services/stdin_input_handler.rb

class StdinInputHandler
  def get_input(prompt)
    print(prompt) # rubocop:disable Rails/Output
    $stdin.gets.chomp.strip
  end

  def get_password(prompt)
    require("io/console")
    print(prompt) # rubocop:disable Rails/Output
    password = $stdin.noecho(&:gets).chomp
    puts # rubocop:disable Rails/Output
    password
  end

  def confirm?(message, default: false)
    suffix = default ? "(Y/n)" : "(y/N)"
    response = get_input("#{message} #{suffix}: ").downcase

    if default
      response != "n" && response != "no"
    else
      %w[y yes].include?(response)
    end
  end
end
