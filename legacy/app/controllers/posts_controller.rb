class PostsController < ApplicationController
  PAGE_METADATA = {
    'home' => {
      title: 'Home',
    },

    'webdev' => {
      title: 'Web Development'
    },

    'photo' => {
      title: 'Photography',
      pages: {
        'emergence' => {
          title: 'Emergence'
        },

        'takoma' => {
          title: 'Takoma'
        },

        'shores' => {
          title: 'Shores'
        },

        'weddings' => {
          title: 'Weddings'
        }
      }
    },

    'contact' => {
      title: 'Contact'
    }
  }.freeze

  before_action :set_page_metadata

  def index
    @posts = Post.recent
  end

  private

  def set_page_metadata
    @pages = PAGE_METADATA
  end
end
