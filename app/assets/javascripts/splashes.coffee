# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/

$(document).on "page:change", ->
  $('.splash-job a').mouseenter ->
    $(this).fadeTo('fast', .35);

  $('.splash-job a').mouseleave ->
    $(this).fadeTo('fast', 1);
