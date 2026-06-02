# frozen_string_literal: true

# Action-nav for the RSS-logs activity-feed index page. Includes the
# "make this filter the default" link iff the current filter differs
# from the user's saved default AND we're not already on the
# make_default flow.
class Tab::RssLog::IndexActions < Tab::Collection
  def initialize(user:, types:, make_default_param:, make_default_path:)
    super()
    @user = user
    @types = types
    @make_default_param = make_default_param
    @make_default_path = make_default_path
  end

  private

  def tabs
    return [] unless show_make_default?

    [Tab::RssLog::MakeDefault.new(path: @make_default_path)]
  end

  def show_make_default?
    @make_default_param != "1" &&
      @user&.default_rss_type.to_s.split.sort != @types
  end
end
