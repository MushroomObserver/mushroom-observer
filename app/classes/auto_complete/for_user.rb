# frozen_string_literal: true

class AutoComplete::ForUser < AutoComplete::ByString
  def rough_matches(letter)
    users = User.select(:login, :name, :id).distinct.
            where(User[:login].matches("#{letter}%").
              or(User[:name].matches("#{letter}%")).
              or(User[:name].matches("% #{letter}%"))).
            order(login: :asc)

    matches_array(users)
  end

  def exact_match(string)
    user = User.select(:login, :name, :id).distinct.
           where(User[:login].eq(string)).or(User[:name].eq(string)).
           order(login: :asc).first
    return [] unless user

    matches_array([user])
  end

  # Turn the instances into hashes, and figure out what name to display
  def matches_array(users)
    matches = users.map do |user|
      user = user.attributes.symbolize_keys
      user[:name] = if user[:name].empty?
                      user[:login]
                    else
                      "#{user[:login]} <#{user[:name]}>"
                    end
      user.except(:login, :bonuses) # idk why this is getting bonuses
    end
    matches.sort_by! { |user| user[:name] }
  end
end
