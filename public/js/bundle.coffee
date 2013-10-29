$ ->
  Window::alert = (cls, msg) ->
    unless msg
      msg = cls
      cls = 'info'
    # error, success, info
    $("<div class=\"alert alert-#{cls}\">#{msg}</div>")
      .insertAfter('#clothe-search-form')
    setTimeout ->
      $('.alert').remove()
    , 3000
  
  pathname = location.pathname
  $('.navbar .nav > li').each (i, el) ->
    if pathname is $(el).children('a').attr('href') then $(el).addClass('active')

$.fn.ForceNumericOnly = ->
  @each ->
    $(@).keydown (e) ->
      console.log e.keyCode
      key = e.charCode or e.keyCode or 0
      key == 8 ||
      key == 9 ||
      key == 46 ||
      key == 110 ||
      key == 190 ||
      (key >= 35 && key <= 40) ||
      (key >= 48 && key <= 57) ||
      (key >= 96 && key <= 105)