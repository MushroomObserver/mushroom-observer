# frozen_string_literal: true

#  News Articles
#
#  Actions
#
#    create:           Create article from data in "new" form
#    destroy::         Destroy article
#    edit::            Display form for editing article
#    index::           List articles, filtered by current query
#    new::             Display form for new article
#    show::            Show one article
#    update::          Update article from "edit" form
#
#  Public methods      None (ideally)
#
class ArticlesController < ApplicationController
  # TODO: use explainig variables/methods in options
  before_action :login_required, except: [
    :index,
    :show
  ]
  before_action :store_location, except: :destroy
  before_action :pass_query_params, except: :index
  before_action :ignore_request_unless_permitted, except: [
    :index,
    :show,
  ]

  # ---------- Actions to Display data (index, show, etc.) ---------------------

  # List selected articles, filtered by current Query.
  # articles  GET /articles(.:format)
  def index
    if params[:q] || params[:by]
      index_filtered
    else
      index_full
    end
  end

  # article  GET /articles/:id(.:format)
  def show
    return false unless (@article = find_or_goto_index(Article, params[:id]))

    @canonical_url = article_url(@article.id)
  end

  # ---------- Actions to Display forms -- (new, edit, etc.) -------------------

  # new_article  GET /articles/new(.:format)
  def new
    @article = Article.new
  end

  # edit_article  GET /articles/:id/edit(.:format)
  def edit
    @article = find_or_goto_index(Article, params[:id])
  end

  # ---------- Actions to Modify data: (create, update, destroy, etc.) ---------

  # POST /articles(.:format)
  def create
    # TODO: use guard clause? See :update BUT see note at flash_missing_title?
    if flash_missing_title?
      render(:new)
      return
    else
      @article = Article.new(
        title: params[:article][:title],
        body: params[:article][:body],
        user_id: @user.id
      )
      @article.save
      redirect_to article_path(@article.id)
    end
  end

  # PATCH /articles/:id(.:format)
  # PUT   /articles/:id(.:format)
  def update
    @article = Article.find(params[:id])
    return render(:edit) if flash_missing_title?

    @article.title = params[:article][:title]
    @article.body = params[:article][:body]

    if @article.changed?
      raise(:runtime_unable_to_save_changes.t) unless @article.save

      flash_notice(:runtime_edit_article_success.t(id: @article.id))
    else
      flash_warning(:runtime_no_changes.t)
    end
    redirect_to article_path(@article.id)
  end

  # DELETE /articles/:id(.:format)
  def destroy
    if (@article = Article.find(params[:id])) && @article.destroy
      flash_notice(:runtime_destroyed_id.t(type: Article, value: params[:id]))
    end
    redirect_to(articles_path)
  end

  # ---------- Public methods (unrouted) ---------------------------------------

  ##############################################################################

  private

  # --------- Filters

  # Filter: Unless user permitted to perform request, just index
  def ignore_request_unless_permitted
    return if helpers.permitted?(@user)

    flash_notice(:permission_denied.t)
    # TODO: Update to 0.88 and see if fixed
    # rubocop disable Style/AndOr
    # RuboCop 0.83 autocorrects the following line to:
    #   redirect_to(action: "index_article") && (return)
    redirect_to(articles_path)
    # rubocop enable Style/AndOr
  end

  # --------- Other private methods

  def index_filtered
    query = find_or_create_query(:Article, by: params[:by])
    show_selected_articles(
      query,
      id: params[:id].to_s,
      always_index: true
    )
  end

  def index_full
    query = create_query(
      :Article,
      :all,
      by: :created_at
    )
    show_selected_articles(query)
  end

  # Show selected list of articles.
  def show_selected_articles(query, args = {})
    args = {
      action: :index,
      letters: "articles.title",
      num_per_page: 50
    }.merge(args)

    @links ||= []

    # Add some alternate sorting criteria.
    args[:sorting_links] = show_sorts

    show_index_of_objects(query, args)
  end

  # TODO: unextract unless needed to avoid metric offense
  def show_sorts
    [
      ["created_at",  :sort_by_created_at.t],
      ["updated_at",  :sort_by_updated_at.t],
      ["user",        :sort_by_user.t],
      ["title",       :sort_by_title.t]
    ].freeze
  end

  # TODO: Revise if possible. Feels overworked with two concerns:
  # supplies a flashh and changes state. Would a better name work?
  #
  # add flash message if title missing
  def flash_missing_title?
    return if params[:article][:title].present?

    flash_error(:article_title_required.t)
    true
  end

  # Retained as a model for other controllers, but
  # Not needed or testable in ArticleController because
  # because it does not mass assign
  #
  # encapsulate parameters allowed to be mass assigned
  # def article_params
  #   params[:article].permit(:body, :title)
  # end
end
