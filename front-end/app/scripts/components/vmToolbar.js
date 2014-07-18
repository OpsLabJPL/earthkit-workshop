define(
  [
    '../../components/flight/lib/component',
    'templates'
  ],

  function(defineComponent, templates) {
    
    return defineComponent(vmToolbar);
    
    function vmToolbar() {
      
      var component;
      
      this.render = function(evt) {
        var templateData = { instances : this.instances, currentLab : this.currentLab };
        
        _.each(templateData.instances, function(instance) {
          instance.ready = instance.status == 'ready';
          instance.progress = (instance.status == 'provisioning') ? 50 : 100;
          instance.stopping = instance.status == 'stopping';
        });
        
        var html = templates['templates/vmToolbar.hbs'](templateData);
        if (this.currentLab) {
          this.$node.html(html).show();
        }

        this.$node.find('.shut-down').click(function(evt) {
          evt.preventDefault();
          if ($(this).hasClass('disabled')) {
            return;
          }
          if (confirm("Are you sure you want to shut down this instance?")) {
            console.log("shutting down ",component.currentLab);
            $(this).addClass('disabled');
            $(document).trigger('terminateInstance', $(this).attr('data-ami'))            
          }
        });
        
        this.$node.find('.launch').click(function(evt) {
          evt.preventDefault();
          if ($(this).hasClass('disabled')) {
            return;
          }
          $(this).addClass('disabled').html("Launching...");
          console.log("launching ",component.currentLab);
          $(document).trigger('launchLabInstance', component.currentLab);
        })
      }
      
      this.after('initialize', function() {
        
        component = this;
        
        this.on(document, 'labLoaded', function(evt, lab) {
          this.currentLab = lab;
          this.render();
        });
        
        this.on(this.attr.loginSelector, 'userChanged', function(evt, username) {
          if (username) {
            this.render();
          } else {
            this.$node.hide();
          }
        });
        
        this.on(document, 'loadedInstances', function(evt, instances) {
          console.log("running instances:", instances);
          this.instances = instances;
          this.render(evt);
        });
        
      });
      
    }
  }
  
);
