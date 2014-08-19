// Generated by CoffeeScript 1.7.1
(function() {
  $(function() {
    var beforeSendSMS, visitError;
    $("#btn-service-disagree").click(function(e) {
      $("input[name=service]").prop("checked", false);
      $("#modal-service .modal-body").scrollTop(0);
      return $("#modal-service").modal('hide');
    });
    $("#btn-service-agree").click(function(e) {
      $("input[name=service]").prop("checked", true);
      $("#modal-service .modal-body").scrollTop(0);
      return $("#modal-service").modal('hide');
    });
    $("input[name=service]").click(function(e) {
      if ($(this).prop("checked")) {
        $(this).prop("checked", false);
        return $("#modal-service").modal('show');
      }
    });
    $("#btn-privacy-disagree").click(function(e) {
      $("input[name=privacy]").prop("checked", false);
      $("#modal-privacy .modal-body").scrollTop(0);
      return $("#modal-privacy").modal('hide');
    });
    $("#btn-privacy-agree").click(function(e) {
      $("input[name=privacy]").prop("checked", true);
      $("#modal-privacy .modal-body").scrollTop(0);
      return $("#modal-privacy").modal('hide');
    });
    $("input[name=privacy]").click(function(e) {
      if ($(this).prop("checked")) {
        $(this).prop("checked", false);
        return $("#modal-privacy").modal('show');
      }
    });
    setTimeout(function() {
      return $('.alert').remove();
    }, 3000);
    visitError = function(msg) {
      return $('#visit-alert').prepend("<div class=\"alert alert-danger\"><button class=\"close\" type=\"button\" data-dismiss=\"alert\">&times;</button>" + msg + "</div>");
    };
    beforeSendSMS = function() {
      $(".sms").removeClass('block').hide();
      $("#btn-sms-confirm-label").html('SMS 인증번호 전송');
      return $("#btn-sms-confirm").prop("disabled", false);
    };
    beforeSendSMS();
    $('#btn-sms-reset').click(function(e) {
      return beforeSendSMS();
    });
    return $('#btn-sms-confirm').click(function(e) {
      var name, phone, privacy, service, sms;
      e.preventDefault();
      name = $("input[name=name]").val();
      phone = $("input[name=phone]").val();
      service = $("input[name=service]").prop("checked");
      privacy = $("input[name=privacy]").prop("checked");
      sms = $("input[name=sms]").val();
      if (name && phone && service && privacy && sms) {
        return $('#visit-form').submit();
      } else {
        if (!name) {
          visitError('이름을 입력해주세요.');
          return;
        }
        if (!phone) {
          visitError('휴대전화를 입력해주세요.');
          return;
        }
        if (!service) {
          visitError('서비스 이용약관을 확인해주세요.');
          return;
        }
        if (!privacy) {
          visitError('개인정보 이용안내를 확인해주세요.');
          return;
        }
        return $.ajax("/api/search/user.json", {
          type: 'GET',
          data: {
            q: phone
          },
          success: function(data, textStatus, jqXHR) {
            var timer, user, validate_end;
            if (data.length !== 1) {
              visitError('휴대전화가 중복되었습니다.');
              return;
            }
            user = data[0];
            if (!/^\d+$/.test(user.phone)) {
              visitError('유효하지 않은 휴대전화입니다.');
              return;
            }
            if (/^999/.test(user.phone)) {
              visitError('전송 불가능한 휴대전화입니다.');
              return;
            }
            if (user.name !== name) {
              visitError('이름과 휴대전화가 일치하지 않습니다.');
              return;
            }
            OpenCloset.sendSMSValidation(phone);
            $(".sms").addClass('block').show();
            $("#btn-sms-confirm-label").html('SMS 인증하기');
            validate_end = moment().add('m', 3);
            $("#sms-remain-seconds").html(validate_end.diff(moment(), 'seconds'));
            return timer = setInterval(function() {
              var validate_remain;
              validate_remain = validate_end.diff(moment(), 'seconds');
              if (validate_remain > 0) {
                return $("#sms-remain-seconds").html(validate_remain);
              } else {
                $("#sms-remain-seconds").html(0);
                $("#btn-sms-confirm").prop("disabled", true);
                return clearInterval(timer);
              }
            }, 500);
          },
          error: function(jqXHR, textStatus, errorThrown) {
            var type, _ref;
            type = (_ref = jqXHR.status === 404) != null ? _ref : {
              'warning': 'danger'
            };
            return visitError('휴대전화가 일치하는 사용자가 없습니다.');
          }
        });
      }
    });
  });

}).call(this);
