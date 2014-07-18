define(
  [
    '../../components/flight/lib/component',
    'templates'
  ],

  function(defineComponent, templates) {
    
    return defineComponent(header);
    
    function header() {
      
      this.render = function(evt, username) {
        var html = templates['templates/header.hbs']({ username : username });
        this.$node.html(html);
        
        var component = this;
        this.$node.find('.logout').click(function(e) {
          e.preventDefault();
          $(component.attr.loginSelector).trigger('logout');
        });
      }
      
      this.after('initialize', function() {
        this.render();
        this.on(this.attr.loginSelector, 'userChanged', function(evt, username) {
          this.render(evt, username);
        })
      })
      
    }
  }
  
);
