# frozen_string_literal: true

class AutoComplete::ForUser < AutoComplete::ByString
  def rough_matches(letter)
    users = User.select(:login, :name).distinct.
            where(User[:login].matches("#{letter}%").
              or(User[:name].matches("#{letter}%")).
              or(User[:name].matches("% #{letter}%"))).
            order(login: :asc).pluck(:login, :name)

    users.map do |login, name|
      name.empty? ? login : "#{login} <#{name}>"
    end.sort
  end
end
