require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'
require 'yaml'

SITEMAP = YAML.load_file('./data/sitemap.yml').freeze

set :bind, '0.0.0.0' if development?

# ====------------------====
# Auxilliary Functions
# ====------------------====

def nonexistent_role?
  !SITEMAP.keys.include? @role
end

def nonexistent_subpage?
  pages = SITEMAP[@role]['pages']
  paths = pages.map { |page| page['path'] }
  !paths.include? @page
end

def render_role_subpage
  if nonexistent_role?
    redirect '/'
  elsif nonexistent_subpage?
    status 404
  else
    erb "#{@role}_#{@page}".to_sym, layout: :main_layout
  end
end

# ====------------------====
# View Helpers
# ====------------------====

helpers do
  def page_path(page_hash)
    "/#{@role}/#{page_hash['path']}"
  end
end

# ====------------------====
# Routes
# ====------------------====

not_found do
  @role ? erb("#{@role}_not_found".to_sym, layout: :main_layout) : redirect('/')
end

get '/' do
  erb :splash, layout: :splash_layout
end

get '/:role' do
  @role = params[:role]

  if SITEMAP.keys.include? @role
    erb @role.to_sym, layout: :main_layout
  else
    redirect '/'
  end
end

get '/:role/:page' do
  @role = params[:role]
  @page = params[:page]

  render_role_subpage
end
