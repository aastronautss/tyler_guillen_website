$(function() {
  function flashElement($ele, times = 1, duration = 500) {
    $ele.addClass('flash-transition');

    for (var i = 0; i < times * 2; i++) {

      setTimeout(function() {
        $ele.addClass('flash');
      }, i * duration );

      i++;

      setTimeout(function() {
        $ele.removeClass('flash');
      }, i * duration);
    }

    setTimeout(function() {
      $ele.removeClass('flash-transition');
    }, duration * times * 2);
  }

  $('.lower-content').addClass('load');

  $('.leave-layout').on('click', function(e) {
    e.preventDefault();
    var url = $(this).attr('href');
    $('.fade-on-leave').addClass('fade-out');

    setTimeout(function() {
      window.location = url;
    }, 400);
  });

  $('.footnote').on('click', function(e) {
    var footnote_id = $(e.target).attr('href').replace(':', '\\:');
    var $footnote = $(footnote_id).children('p').first();

    flashElement($footnote, 2);
  });

  $('.reversefootnote').on('click', function(e) {
    var footnote_ref_id = $(e.target).attr('href').replace(':', '\\:');
    var $footnote_ref = $(footnote_ref_id).closest('p').first();

    flashElement($footnote_ref, 2);
  });
});
