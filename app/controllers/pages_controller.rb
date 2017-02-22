class PagesController < ApplicationController
  include HighVoltage::StaticPage

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

  private

  def set_page_metadata
    @pages = PAGE_METADATA
  end
end
