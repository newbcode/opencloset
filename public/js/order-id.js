// Generated by CoffeeScript 1.6.3
(function() {
  $(function() {
    var autoSetByAdditionalDay, refreshReturnButton, selectSearchedClothes, setOrderDetailFinalPrice, updateOrder;
    updateOrder = function() {
      var order_id;
      order_id = $('#order').data('order-id');
      return $.ajax("/api/order/" + order_id + ".json", {
        type: 'GET',
        success: function(data, textStatus, jqXHR) {
          var compiled;
          $(".order-price").html(OpenCloset.commify(data.price) + '원');
          compiled = _.template($('#tpl-late-fee').html());
          $("#late-fee").html($(compiled(data)));
          return $('#order-late-fee-pay-with').editable({
            source: function() {
              var m, _i, _len, _ref, _results;
              _ref = ['현금', '카드', '현금+카드'];
              _results = [];
              for (_i = 0, _len = _ref.length; _i < _len; _i++) {
                m = _ref[_i];
                _results.push({
                  value: m,
                  text: m
                });
              }
              return _results;
            }
          });
        },
        error: function(jqXHR, textStatus, errorThrown) {},
        complete: function(jqXHR, textStatus) {}
      });
    };
    updateOrder();
    $('span.order-status.label').each(function(i, el) {
      return $(el).addClass(OpenCloset.status[$(el).data('order-detail-status')].css);
    });
    $('#order-staff-name').editable();
    $('#order-additional-day').editable({
      source: function() {
        var m, _i, _results;
        _results = [];
        for (m = _i = 0; _i <= 20; m = ++_i) {
          _results.push({
            value: m,
            text: "" + (m + 3) + "박 " + (m + 4) + "일"
          });
        }
        return _results;
      },
      success: function(response, newValue) {
        $(this).data('value', newValue);
        return autoSetByAdditionalDay();
      }
    });
    $('#order-rental-date').editable({
      mode: 'inline',
      showbuttons: 'true',
      type: 'combodate',
      emptytext: '비어있음',
      format: 'YYYY-MM-DD',
      viewformat: 'YYYY-MM-DD',
      template: 'YYYY-MM-DD',
      combodate: {
        minYear: 2013
      },
      url: function(params) {
        var data, url;
        url = $('#order').data('url');
        data = {};
        data[params.name] = params.value;
        return $.ajax(url, {
          type: 'PUT',
          data: data
        });
      },
      success: function(response, newValue) {
        return updateOrder();
      }
    });
    $('#order-target-date').editable({
      mode: 'inline',
      showbuttons: 'true',
      type: 'combodate',
      emptytext: '비어있음',
      format: 'YYYY-MM-DD',
      viewformat: 'YYYY-MM-DD',
      template: 'YYYY-MM-DD',
      combodate: {
        minYear: 2013
      },
      url: function(params) {
        var data, url;
        url = $('#order').data('url');
        data = {};
        data[params.name] = params.value + ' 23:59:59';
        return $.ajax(url, {
          type: 'PUT',
          data: data
        });
      },
      success: function(response, newValue) {
        return updateOrder();
      }
    });
    $('#order-price-pay-with').editable({
      source: function() {
        var m, _i, _len, _ref, _results;
        _ref = ['현금', '카드', '현금+카드'];
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          m = _ref[_i];
          _results.push({
            value: m,
            text: m
          });
        }
        return _results;
      }
    });
    $('.order-detail').editable();
    setOrderDetailFinalPrice = function(order_detail_id) {
      var day, final_price, price;
      day = parseInt($('#order-additional-day').data('value'));
      price = parseInt($("#order-detail-price-" + order_detail_id).data('value'));
      final_price = price + price * 0.2 * day;
      $("#order-detail-final-price-" + order_detail_id).editable('setValue', final_price);
      return $("#order-detail-final-price-" + order_detail_id).editable('submit');
    };
    $('.order-detail-price').each(function(i, el) {
      return $(el).editable({
        display: function(value, sourceData, response) {
          return $(this).html(OpenCloset.commify(value));
        },
        success: function(response, newValue) {
          $(el).data('value', newValue);
          updateOrder();
          return setOrderDetailFinalPrice($(el).data('pk'));
        }
      });
    });
    $('#order-desc').editable();
    $('.order-detail-final-price').editable({
      display: function(value, sourceData, response) {
        return $(this).html(OpenCloset.commify(value));
      },
      success: function(response, newValue) {
        return updateOrder();
      }
    });
    $('#btn-order-confirm').click(function(e) {
      var order_id, redirect_url, url;
      order_id = $('#order').data('order-id');
      url = $(e.target).data('url');
      redirect_url = $(e.target).data('redirect-url');
      if (!url) {
        return;
      }
      if (!order_id) {
        return;
      }
      return $.ajax("/api/order/" + order_id + ".json", {
        type: 'GET',
        success: function(data, textStatus, jqXHR) {
          if (!data.staff_id) {
            alert('danger', '담당자를 입력하세요.');
            return;
          }
          if (!(data.additional_day >= 0)) {
            alert('danger', '대여 기간을 입력하세요.');
            return;
          }
          if (!data.rental_date) {
            alert('danger', '대여일을 입력하세요.');
            return;
          }
          if (!data.target_date) {
            alert('danger', '반납 예정일을 입력하세요.');
            return;
          }
          if (!data.price_pay_with) {
            alert('danger', '대여비 납부 여부를 확인하세요.');
            return;
          }
          return $.ajax(url, {
            type: 'POST',
            data: {
              id: order_id,
              name: 'status_id',
              value: 2,
              pk: order_id
            },
            success: function(data, textStatus, jqXHR) {
              return window.location.href = redirect_url;
            },
            error: function(jqXHR, textStatus, errorThrown) {
              return alert('danger', jqXHR.responseJSON.error);
            },
            complete: function(jqXHR, textStatus) {}
          });
        },
        error: function(jqXHR, textStatus, errorThrown) {},
        complete: function(jqXHR, textStatus) {}
      });
    });
    autoSetByAdditionalDay = function() {
      var day;
      if ($('#order-additional-day').data('disabled')) {
        return;
      }
      day = parseInt($('#order-additional-day').data('value'));
      $('#order-rental-date').editable('setValue', moment().format('YYYY-MM-DD HH:mm:ss'), true);
      $('#order-rental-date').editable('submit');
      $('#order-target-date').editable('setValue', moment().add('days', day + 3).endOf('day').format('YYYY-MM-DD HH:mm:ss'), true);
      $('#order-target-date').editable('submit');
      $('#order table td:nth-child(5) span').html("4+" + day + "일");
      return $('.order-detail-price').each(function(i, el) {
        return setOrderDetailFinalPrice($(el).data('pk'));
      });
    };
    autoSetByAdditionalDay();
    $('#btn-return-process').click(function(e) {
      $(".return-process input[data-clothes-code]").prop('checked', 0);
      $('.return-process').show();
      $('.return-process-reverse').hide();
      return $('#clothes-search').val('').focus();
    });
    $('#btn-return-cancel').click(function(e) {
      $(".return-process input[data-clothes-code]").prop('checked', 0);
      $('.return-process').hide();
      return $('.return-process-reverse').show();
    });
    refreshReturnButton = function() {
      var count, total;
      count = 0;
      total = 0;
      $(".return-process input[data-clothes-code]").each(function(i, el) {
        if ($(el).prop('checked')) {
          ++count;
        }
        return ++total;
      });
      if (count > 0) {
        if (count === total) {
          $('#btn-return-all').removeClass('disabled');
          return $('#btn-return-part').addClass('disabled');
        } else {
          $('#btn-return-all').addClass('disabled');
          return $('#btn-return-part').removeClass('disabled');
        }
      } else {
        $('#btn-return-all').addClass('disabled');
        return $('#btn-return-part').addClass('disabled');
      }
    };
    $(".return-process input[data-clothes-code]").click(function() {
      return refreshReturnButton();
    });
    selectSearchedClothes = function() {
      var clothes_code;
      clothes_code = OpenCloset.trimClothesCode($('#clothes-search').val());
      $('#clothes-search').val('').focus();
      $(".return-process input[data-clothes-code=" + clothes_code + "]").prop('checked', 1);
      return refreshReturnButton();
    };
    $('#clothes-search').keypress(function(e) {
      if (e.keyCode === 13) {
        return $('#btn-clothes-search').click();
      }
    });
    return $('#btn-clothes-search').click(function() {
      return selectSearchedClothes();
    });
  });

}).call(this);
