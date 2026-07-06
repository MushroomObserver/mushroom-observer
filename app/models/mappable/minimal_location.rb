# frozen_string_literal: true

module Mappable
  class MinimalLocation < Box
    attribute :id, :integer
    attribute :name, :string

    validates :id, presence: true
    validates :name, presence: true

    def display_name(user = nil)
      ::Location.user_format(user, name)
    end
  end
end
