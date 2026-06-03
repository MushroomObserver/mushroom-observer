# frozen_string_literal: true

# Sidebar login section — shown when no user is signed in.
class Tab::Sidebar::LoginActions < Tab::Collection
  private

  def tabs
    [Tab::Sidebar::Login.new,
     Tab::Sidebar::Signup.new]
  end
end
