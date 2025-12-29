# frozen_string_literal: true

class Autocomplete::ForUser < Autocomplete::ByString
  def rough_matches(letter)
    users = User.verified.select(:login, :name, :id).distinct.
            where(User[:login].matches("#{letter}%").
              or(User[:name].matches("#{letter}%")).
              or(User[:name].matches("% #{letter}%"))).
            order(name: :asc, login: :asc)

    matches_array(users)
  end

  def exact_match(string)
    # Handle "Name (login)" format from unique_text_name
    search_login = parse_login_from_display_format(string)
    search_string = string.downcase

    user = User.verified.select(:login, :name, :id).distinct.
           where(User[:login].downcase.eq(search_login || search_string).
             or(User[:name].downcase.eq(search_string))).
           order(login: :asc).first
    return [] unless user

    matches_array([user])
  end

  private

  # Parse login from "Name (login)" format, return nil if not in that format
  def parse_login_from_display_format(string)
    match = string.match(/\(([^)]+)\)\s*$/)
    match ? match[1].downcase : nil
  end

  # Turn the instances into hashes, and figure out what name to display
  def matches_array(users)
    matches = users.map do |user|
      name = user.unique_text_name
      user = user.attributes.symbolize_keys
      user[:name] = name
      user.except(:login, :bonuses) # idk why this is getting bonuses
    end
    matches.sort_by! { |user| user[:name] }
  end
end
