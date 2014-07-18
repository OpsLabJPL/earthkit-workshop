define(
  [
    '../../components/flight/lib/component',
    '../../components/crossroads.js/dist/crossroads',
    'hashchange'
  ],

  function(defineComponent, crossroads) {
    
    return defineComponent(router);
    
    function router() {
      
      this.navigateTo = function(evt, path) {
        crossroads.parse(path);
      }
      
      this.after('initialize', function() {
        
        crossroads.addRoute('/', function() {
          $('#lab-list-container').show();
          $('#current-lab').hide();
          $('a').blur();
          $('body').addClass('lab-list');
          $('#console').trigger('hide');
        });
        
        crossroads.addRoute('/labs/{labId}/steps/{step}', function(labId, step) {
          $('#current-lab').trigger('loadLabStep', [labId, step]);
          $('body').removeClass('lab-list');
          $('#console').trigger('show');
        });
        
        var router = this;
        $(window).hashchange(function() {
          var initialPath = window.location.hash.replace(/^#/,'');
          router.navigateTo(null, initialPath);
        }).trigger('hashchange');
        
      })
      
    }
    
  }
);
