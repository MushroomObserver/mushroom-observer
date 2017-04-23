#  News Articles
#
#  Actions
#
#    create_article::   Create new news article
#    show_article::
#    list_article::     List all articles in inverse order of creation
#
class ArticleController < ApplicationController
  # Callbacks
  before_action :login_required, except: [
    :index,
    :show_article
  ]

  # Create a new article
  # :norobots:
  def create_article
    raise(:create_article_not_allowed.t) unless in_admin_mode?
    return unless request.method == "POST"

    article = Article.new(name:    params[:article][:name],
                          body:    params[:article][:body],
                          user_id: @user.id)
    article.save
    redirect_to(action: "show_article", id: article.id) and return
  end

  def index
    store_location
    @articles = Article.all.order(created_at: :desc)
  end

  def show_article
    store_location
    return false unless @article = find_or_goto_index(Article, params[:id])
    @canonical_url = "#{MO.http_domain}/article/show_article/#{@article.id}"
  end

  ##############################################################################

  private

  def whitelisted_article_params
    params[:article].permit(:author, :body, :title)
  end
end
