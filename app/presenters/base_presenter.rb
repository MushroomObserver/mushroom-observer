# frozen_string_literal: true

# https://nithinbekal.com/posts/rails-presenters/
# By inheriting from Ruby’s builtin SimpleDelegator class and calling super
# in the initialize method, we make sure that if we call any method that is
# not defined in the presenter, it passes it on to the model object.
class BasePresenter < SimpleDelegator
  def initialize(model, view)
    @view = view
    super(model)
  end

  # h is a convention for the view context, to access helpers
  def h
    @view
  end
end
