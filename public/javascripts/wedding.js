var app = {
  $form: $('form'),
  templates: {},
  max_guests: 5,

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
      if (val === 'false') { app.guests.reset(); }
      $('#plus_one').slideToggle(val === 'true');
    });

    $('#add_guest').on('click', this.addGuest.bind(this));
  },

  init: function() {
    this.cacheTemplates(),
    this.guests = new this.Guests();
    this.bind();

    // $('#name').focus();
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

  updateButton: function() {
    $('#add_guest').prop('disabled', this.length >= 5);
  },

  setLastID: function() {
    if (this.isEmpty()) { return; }
    this.last_id = this.last().get('id');
  },

  nextID: function() {
    return ++this.last_id;
  },

  initialize: function() {
    this.on('update', this.updateButton.bind(this));
  }
});

app.GuestView = Backbone.View.extend({
  tagName: 'li',

  events: {
    'click a.delete': 'remove'
  },

  clear: function() {
    app.guests.updateButton();
    this.$el.remove();
  },

  remove: function(e) {
    if (e.preventDefault) { e.preventDefault(); }
    var id = +this.$el.data('id');
    this.model.collection.remove(id);
    app.guests.updateButton();
    this.$el.remove();
  },

  render: function() {
    this.$el.data('id', this.model.get('id'));
    this.$el.html(this.template(this.model.toJSON()));
  },

  initialize: function() {
    this.template = app.templates.guest;
    this.render();
    this.listenTo(this.model, 'remove', this.remove);
    this.listenTo(this.model.collection, 'reset', this.clear);
  }
});

$(function() { app.init(); });
