# frozen_string_literal: true

#  News Articles
#
#  Actions
#
#    create:           Create article from data in "new" form
#    destroy::         Destroy article
#    edit::            Display form for editing article
#    index::           List all articles
#    index_articles::  List selected (based on last search) articles
#    new::             Display form for new article
#    show::            Show one article
#    update::          Update article from "edit" form
#
#
#  Callbacks and Methods
#
#    ignore_request_unless_permitted:: Unless user permitted to perform request,
#                       then index_articles
#    permitted?         boolean: permitted to create/update/destroy Articles
#
class ArticlesController < ApplicationController
  before_action :login_required, except: [
    :index,
    :index_articles,
    :list_articles, # aliased
    :show,
    :show_article # aliased
  ]
  before_action :store_location
  before_action :ignore_request_unless_permitted, except: [
    :index,
    :index_articles,
    :list_articles, # aliased
    :show,
    :show_article # aliased
  ]

  ############ - Actions to Display data (index, show, etc.)

  # List selected articles, based on current Query.
  def index_articles
    query = find_or_create_query(:Article, by: params[:by])
    show_selected_articles(
      query,
      id: params[:id].to_s,
      always_index: true
    )
  end

  # List all articles
  def index
    query = create_query(
      :Article,
      :all,
      by: :created_at
    )
    show_selected_articles(query)
  end

  alias_method :list_articles, :index

  # Display one Article
  def show
    return false unless (@article = find_or_goto_index(Article, params[:id]))

    @canonical_url = "#{MO.http_domain}/articles/#{@article.id}"
  end

  alias_method :show_article, :show

  ############ Actions to Display forms -- (new, edit, etc.)

  def new
    @article = Article.new
  end

  alias_method :create_article, :new

  # Edit existing article
  def edit
    pass_query_params
    @article = find_or_goto_index(Article, params[:id])
  end

  alias_method :edit_article, :edit

  ############ Actions to Modify data: (create, update, destroy, etc.)

  def create
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

  def update
    pass_query_params
    @article = Article.find(params[:id])
    return if flash_missing_title?

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

  alias_method :save_edits, :update

  def destroy
    pass_query_params
    if (@article = Article.find(params[:id])) && @article.destroy
      flash_notice(:runtime_destroyed_id.t(type: Article, value: params[:id]))
    end
    redirect_to action: :index_article
  end

  alias_method :destroy_article, :destroy

  ############ Public methods (unrouted)

  # permitted to create/update/destroy any Article
  def permitted?
    Article.can_edit?(@user)
  end

  helper_method :permitted?

  ##############################################################################

  private

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

  def show_sorts
    [
      ["created_at",  :sort_by_created_at.t],
      ["updated_at",  :sort_by_updated_at.t],
      ["user",        :sort_by_user.t],
      ["title",       :sort_by_title.t]
    ].freeze
  end

  # Unless user permitted to perform request, just index_articles
  def ignore_request_unless_permitted
    return if permitted?

    flash_notice(:permission_denied.t)
    # rubocop disable Style/AndOr
    # RuboCop 0.83 autocorrects the following line to:
    #   redirect_to(action: "index_article") && (return)
    redirect_to(articles_path)
    # rubocop enable Style/AndOr
  end

  # add flash message if title missing
  def flash_missing_title?
    return if params[:article][:title].present?

    flash_error(:article_title_required.t)
    true
  end

  # encapsulate parameters allowed to be mass assigned
  # Not needed or testable because this controller does not mass assign
  # def article_params
  #   params[:article].permit(:body, :title)
  # end
end
