class PostsController < ApplicationController
  def index
    @posts = Post.recent
  end
end
