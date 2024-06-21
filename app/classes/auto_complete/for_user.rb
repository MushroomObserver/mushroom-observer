# frozen_string_literal: true

class AutoComplete::ForUser < AutoComplete::ByString
  def rough_matches(letter)
    users = User.select(:login, :name, :id).distinct.
            where(User[:login].matches("#{letter}%").
              or(User[:name].matches("#{letter}%")).
              or(User[:name].matches("% #{letter}%"))).
            order(login: :asc).pluck(:login, :name, :id)

    users.map! do |login, name, id|
      user_name = name.empty? ? login : "#{login} <#{name}>"
      { name: user_name, id: id }
    end
    users.sort_by! { |user| user[:name] }
  end
end
