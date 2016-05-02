$(function() {
  $(".nav-parent").on('click', function(e) {
    e.preventDefault();
    $parent = $(e.target);
    $list = $parent.next("ul");

    $list.fadeToggle();
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
