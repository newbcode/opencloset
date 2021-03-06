$ ->
  $(".chosen-select").chosen({ width: '100%' })

  $('span.category').each (i, el) ->
    $(el).html OpenCloset.category[ $(el).data('category') ].str

  $('span.color').each (i, el) ->
    $(el).html OpenCloset.color[ $(el).data('color') ]

  $('#btn-rent-search').click (e) ->
    category   = $("select[name=category]").val()
    gender     = $("select[name=gender]").val()
    limit      = $("#limit").val()
    status_ids = $("select[name=status_ids]").val()
    sort       = $("select[name=sort]").val()

    unless /^\d+$/.test( limit )
      OpenCloset.alert 'danger', '유효하지 않은 입력값입니다.'
      $('input[name=limit]').focus()
      return

    window.location = "/stat/clothes/rent/#{category}?#{$.param({ gender: gender, limit: limit, status_ids: status_ids, sort: sort })}"
