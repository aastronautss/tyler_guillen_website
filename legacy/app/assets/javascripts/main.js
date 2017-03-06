$(function() {
  $('.lower-content').addClass('load');

  $('.leave-main-layout').on('click', function(e) {
    e.preventDefault();
    var url = $(this).attr('href');
    $('.fade-on-leave').addClass('fade-out');

    setTimeout(function() {
      window.location = url;
    }, 400);
  });
});
