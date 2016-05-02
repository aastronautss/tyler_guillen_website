require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require 'tilt/erubis'
require 'redcarpet'
require 'yaml'

set :bind, '0.0.0.0' if development?

@root = File.expand_path("..", __FILE__)

SITEMAP = YAML.load_file(@root + '/data/sitemap.yml').freeze

# ====------------------====
# Auxilliary Functions
# ====------------------====

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render text
end

# TODO: DRY up the 'not found' logic.

def nonexistent_role?
  !SITEMAP.keys.include? @role
end

def nonexistent_page?
  pages = SITEMAP[@role]['pages']
  paths = pages.map { |page| page['path'] }
  !paths.include? @page
end

def nonexistent_subpage?
  pages = SITEMAP[@role][@page]['pages']
  paths = pages.map { |page| page['path'] }
  !paths.include? @page
end

def render_role_page
  if nonexistent_role?
    redirect '/'
  elsif nonexistent_page?
    status 404
  else
    erb "#{@role}_#{@page}".to_sym, layout: :main_layout
  end
end

def render_subpage
  if nonexistent_role?
    redirect '/'
  elsif nonexistent_page?
    status 404
  else
    erb "#{@role}_#{@page}_#{@subpage}".to_sym, layout: :main_layout
  end
end

# ====------------------====
# View Helpers
# ====------------------====

helpers do
  def render_content(filename)
    path = "data/#{filename}"
    content = File.read path
    render_markdown content
  end

  def child_pages? page_hash
    !!page_hash['pages']
  end

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

  render_role_page
end

get '/:role/:page/:subpage' do
  @role = params[:role]
  @page = params[:page]
  @subpage = params[:subpage]

  render_subpage
end
