var app = {
  $form: $('form'),
  templates: {},

  addGuest: function(e) {
    e.preventDefault();
    model = this.guests.add({});
    view = new this.GuestView({ model: model });
    view.$el.appendTo('ul').show('slow');
  },

  cacheTemplates: function() {
    $('[type="text/x-handlebars"]').each(function() {
      app.templates[$(this).attr('id')] = Handlebars.compile($(this).html());
    });
  },

  bind: function() {
    $(':radio').on('change', function() {
      var val = $(':radio:checked').val();
      $('#plus_one').slideToggle(val === 'true');
    });

    $('#add_guest').on('click', this.addGuest.bind(this));
  },

  init: function() {
    this.cacheTemplates(),
    this.guests = new this.Guests();
    this.bind();
  }
};

app.Guest = Backbone.Model.extend({
  idAttribute: 'id',

  initialize: function() {
    if (!this.get('id')) {
      this.set('id', this.collection.nextID());
    }
  }
});

app.Guests = Backbone.Collection.extend({
  model: app.Guest,
  last_id: 0,

  setLastID: function() {
    if (this.isEmpty()) { return; }
    this.last_id = this.last().get('id');
  },

  nextID: function() {
    return ++this.last_id;
  }
});

app.GuestView = Backbone.View.extend({
  tagName: 'li',

  events: {
    'click a.delete': 'remove'
  },

  render: function() {
    this.$el.data('id', this.model.get('id'));
    this.$el.html(this.template(this.model.toJSON()));
  },

  initialize: function() {
    this.template = app.templates.guest;
    this.render();
    this.listenTo(this.model, 'remove', this.remove);
  }
});

$(function() { app.init(); });

/* $(function() {
  var templates = {},
      $guest_forms = $('#guest_forms');

  function cacheTemplates() {
    $('[type="text/x-handlebars"]').each(function() {
      templates[$(this).attr('id')] = Handlebars.compile($(this).html());
    });
  }

  function renderGuestForms(size) {
    var $el = $('<div />')
    for (var i = 1; i <= size; i++) {
      $el.append(templates.guest(i));
    }
    $guest_forms.html($el.html());

    $('.optional').toggle(size > 0);
  }

  $('[name=guests]').on('change', function() {
    var size = +$(this).val();
    renderGuestForms(size);
  });

  $(':radio').on('change', function() {
    var val = $(':radio:checked').val();
    $('#plus_one').slideToggle(val === 'true');
  });

  cacheTemplates();
}); */
