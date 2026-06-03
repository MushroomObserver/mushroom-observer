# frozen_string_literal: true

# Sidebar "Observations" section. Latest is always shown; user-only
# items (new / yours / identify) only when a user is logged in.
class Tab::Sidebar::ObservationsActions < Tab::Collection
  def initialize(user: nil)
    super()
    @user = user
  end

  private

  def tabs
    base = [Tab::Sidebar::Observations::Latest.new]
    return base unless @user

    base + [Tab::Sidebar::Observations::New.new,
            Tab::Sidebar::Observations::Yours.new(user: @user),
            Tab::Sidebar::Observations::Identify.new]
  end
end
