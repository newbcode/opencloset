// Generated by CoffeeScript 1.7.1
(function() {
  $(function() {
    return $("#query").datepicker({
      todayHighlight: true,
      autoclose: true
    }).on('changeDate', function(e) {
      var ymd;
      ymd = $('#query').prop('value');
      return window.location = "/booking/" + ymd;
    });
  });

}).call(this);
