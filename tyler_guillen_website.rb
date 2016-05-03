require 'sinatra'
require 'sinatra/reloader' if development?
require 'pry' if development?
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

def find_section dir
  path = dir[0]
  SITEMAP.find { |section| section['path'] == path }
end

def find_page dir
  path = dir[1]
  if @section
    @section['pages'].find { |page| page['path'] == path }
  else
    nil
  end
end

def valid_dir? dir, pages = SITEMAP
  return true if pages.nil? || dir.empty?

  aux_dir = dir.clone
  node = aux_dir.shift
  pages.any? do |page|
    page['path'] == node && valid_dir?(aux_dir, page['pages'])
  end
end

def render_dir(dir)
  if valid_dir? dir
    @section = find_section dir
    @page = find_page dir
    erb dir.join('_').to_sym, layout: :main_layout
  else
    status 404
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
    "/#{@section['path']}/#{page_hash['path']}"
  end
end

# ====------------------====
# Routes
# ====------------------====

not_found do
  redirect '/'
end

get '/' do
  erb :splash, layout: :splash_layout
end

get %r{/([\w\/]*)} do
  dir = params[:captures][0].split('/')
  render_dir dir
end
