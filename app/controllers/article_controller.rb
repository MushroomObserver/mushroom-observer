#  News Articles
#
#  Actions
#
#    create_article::   Create new news article
#    destroy_article::  Destroy article
#    edit_article::     Update article
#    index::            List all articles in inverse order of creation
#    show_article::     Show article
#
#  Methods in public interface
#
#    permitted?         boolean: permitted to create/update/destroy Articles
#
class ArticleController < ApplicationController
  ### Callbacks
  before_action :login_required, except: [
    :index,
    :show_article
  ]
  before_action :store_location

  ### Actions and other Methods
  # Create a new article
  # :norobots:
  def create_article
    write_permission_denied and return unless permitted?

    return unless request.method == "POST"
    article = Article.new(name:    params[:article][:name],
                          body:    params[:article][:body],
                          user_id: @user.id)
    article.save
    redirect_to(action: "show_article", id: article.id)
  end

  def write_permission_denied
    flash_notice(:permission_denied.t)
    redirect_to(action: "index")
  end

  # Edit existing article
  # :norobots:
  def edit_article
    write_permission_denied and return unless permitted?

    pass_query_params
    @article = find_or_goto_index(Article, params[:id].to_s)
    article_not_found unless @article
    return unless request.method == "POST"

    @article.name = params[:article][:name]
    @article.body = params[:article][:body]
    if @article.changed?
      if @article.save
        flash_notice(:runtime_edit_article_success.t(id: @article.id))
      else
        raise(:runtime_unable_to_save_changes.t)
      end
    end
    redirect_to(action: "show_article", id: @article.id)
  end

  def article_not_found
    rescue RuntimeError => err
    reload_edit_name_form_on_error(err)
  end

  def reload_edit_article_form_on_error(err)
    flash_error(err.to_s) unless err.blank?
    flash_object_errors(@article)
  end

  # List all articles in inverse order of creation
  def index
    @articles = Article.all.order(created_at: :desc)
  end

  # Display one Article
  def show_article
    return false unless @article = find_or_goto_index(Article, params[:id])
    @canonical_url = "#{MO.http_domain}/article/show_article/#{@article.id}"
  end

  # Destroy one article
  # :norobots:
  def destroy_article
    write_permission_denied and return unless permitted?

    pass_query_params
    if (@article = Article.find(params[:id])) && @article.destroy
      flash_notice(:runtime_destroyed_id.t(type: Article, value: params[:id]))
    end
    redirect_to(action: "index")
  end

  # permitted to create/update/destroy any Article
  def permitted?
    in_admin_mode?
  end
  helper_method :permitted?

  ##############################################################################

  private

  def whitelisted_article_params
    params[:article].permit(:body, :title)
  end
end
