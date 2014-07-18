define(
  [
    '../../components/flight/lib/component',
    'templates'
  ],

  function(defineComponent, templates) {
    
    
    return defineComponent(labPicker);
    
    function labPicker() {
      
      this.render = function(evt, labList) {
        var html = templates['templates/labPicker.hbs']({ labs : labList })
        this.$node.html(html);
        
        this.$node.find('a').click(function(e) {
          $(this).closest('.thumbnails li').addClass('loading');
        })
      }
          
      
      this.after('initialize', function() {
        this.on(document, 'labListLoaded', this.render);
      })
      
    }
  }
  
);
