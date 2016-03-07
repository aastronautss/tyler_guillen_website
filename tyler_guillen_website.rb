require 'sinatra'
require 'sinatra/reloader' if development?
require 'sinatra/content_for'
require "tilt/erubis"

get '/' do
  erb :splash, layout: :splash_layout
end
