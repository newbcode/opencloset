$ ->
  ## Global variable
  userID = undefined

  ## main
  $('#input-phone').ForceNumericOnly()

  #
  # step1 - 대여자 검색과 대여자 선택을 연동합니다.
  #
  add_registered_guest = ->
    query = $('#guest-search').val()

    return unless query

    $.ajax "/new-borrower.json",
      type: 'GET'
      data: { q: query }
      success: (guests, textStatus, jqXHR) ->
        compiled = _.template($('#tpl-new-borrower-guest-id').html())
        _.each guests, (guest) ->
          unless $("#guest-search-list input[data-guest-id='#{guest.id}']").length
            $html = $(compiled(guest))
            $html.find('input').attr('data-json', JSON.stringify(guest))
            $("#guest-search-list").prepend($html)
      error: (jqXHR, textStatus, errorThrown) ->
        alert('error', jqXHR.responseJSON.error)
      complete: (jqXHR, textStatus) ->

  $('#guest-search-list').on 'click', ':radio', (e) ->
    userID = $(@).val()
    return if $(@).val() is '0'
    g = JSON.parse($(@).attr('data-json'))
    _.each ['name','email','gender','phone','age',
            'address','height','weight','purpose',
            'chest','waist','arm','length','domain'], (name) ->
      $input = $("input[name=#{name}]")
      if $input.attr('type') is 'radio' or $input.attr('type') is 'checkbox'
        $input.each (i, el) ->
          $(el).attr('checked', true) if $(el).val() is g[name]
      else
        $input.val(g[name])

  $('#guest-search').keypress (e) -> add_registered_guest() if e.keyCode is 13
  $('#btn-guest-search').click -> add_registered_guest()

  #
  #
  #

  $('.clickable.label').click ->
    $('#input-purpose').val($(@).text())

  $('#input-target-date').datepicker
    startDate: "-0d"
    language: 'kr'
    format: 'yyyy-mm-dd'
    autoclose: true

  $('#btn-sendsms:not(.disabled)').click (e) ->
    e.preventDefault()
    $this = $(@)
    $this.addClass('disabled')
    to = $('#input-phone').val()
    return unless to
    $.ajax "/sms.json",
      type: 'POST'
      data: { to: to }
      success: (data, textStatus, jqXHR) ->
        alert('success', "#{to} 번호로 SMS 가 발송되었습니다")
      error: (jqXHR, textStatus, errorThrown) ->
        alert('error', jqXHR.responseJSON.error)
      complete: (jqXHR, textStatus) ->
        $this.removeClass('disabled')

  validation = false
  $('#fuelux-wizard').ace_wizard()
    .on 'change', (e, info) ->
      if info.step is 1 && validation
        return false unless $('#validation-form').valid()

      ajax = {}
      switch info.step
        when 2
          ajax.type = 'POST'
          ajax.path = '/users.json'
          if userID and userID isnt '0'
            ajax.type = 'PUT'
            ajax.path = "/users/#{userID}.json"
          $.ajax ajax.path,
            type: ajax.type
            data: $('form').serialize()
            success: (data, textStatus, jqXHR) ->
              userID = data.id
              return true
            error: (jqXHR, textStatus, errorThrown) ->
              alert('error', jqXHR.responseJSON.error)
              return false
            complete: (jqXHR, textStatus) ->
        when 4
          $.ajax "/guests/#{userID}.json",
            type: 'GET'
            success: (data, textStatus, jqXHR) ->
              ajax.type = 'PUT'
              ajax.path = "/guests/#{userID}.json"
            error: (jqXHR, textStatus, errorThrown) ->
              if jqXHR.status is 404
                ajax.type = 'POST'
                ajax.path = "/guests.json?user_id=#{userID}"
              else
                alert('error', jqXHR.responseJSON.error)
                return false
            complete: (jqXHR, textStatus) ->
              $.ajax ajax.path,
                type: ajax.type
                data: $('form').serialize()
                success: (data, textStatus, jqXHR) ->
                  return true
                error: (jqXHR, textStatus, errorThrown) ->
                  alert('error', jqXHR.responseJSON.error)
                  return false
                complete: (jqXHR, textStatus) ->
        else return
        
    .on 'finished', (e) ->
      e.preventDefault()
      guestID = $('input[name=guest-id]:checked').val()
      chest = $("input[name=chest]").val()
      waist = $("input[name=waist]").val()
      location.href = "/search?q=#{parseInt(chest) + 3}/#{waist}//1/&gid=#{userID}"
      false
    .on 'stepclick', (e) ->

  why = $('#guest-why').tag({
    placeholder: $('#guest-why').attr('placeholder'),
    source: [
      '입사면접',
      '사진촬영',
      '결혼식',
      '장례식',
      '입학식',
      '졸업식',
      '세미나',
      '발표',
    ],
  })
  $('.guest-why .clickable.label').click ->
    text = $(@).text()
    e = $.Event('keydown', { keyCode: 13 })
    why.next().val(text).trigger(e)
