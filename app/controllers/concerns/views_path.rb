# http://thepry.github.io/rails-controllers-hierarchy-and-views
# app/controllers/concerns/views_path.rb
module ViewsPath
  def add_views_path(path)
    before_filter do
      lookup_context.prefixes << path
    end
  end
end
