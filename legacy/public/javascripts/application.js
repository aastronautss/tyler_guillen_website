$(function() {
  $(".nav-parent").hover(function() {
    $(this).children('.sub-menu').fadeIn();
  }, function() {
    $(this).children('.sub-menu').fadeOut();
  });

  /* var photo_tile = {
    $tiles: $(".photo_tile"),

    bind: function() {
      $tiles.hover(function(e) {
        $(e.target).find(".tile_overlay").show();
      }, function(e) {
        $(e.target).find(".tile_overlay").hide();
      });
    },

    init: function() {
      this.bind();
    }
  }; */
});