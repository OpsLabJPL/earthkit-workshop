define(
  [
    '../../components/flight/lib/component',
    'templates',
  ],

  function(defineComponent, templates) {
    
    
    return defineComponent(labView);
    
    function labView() {
      
      this.currentLab;
      
      this.render = function(evt, lab, stepNumber) {
        _.each(lab.steps, function(step){ 
          if (step != _.last(lab.steps)) {
            step.nextStep = step.index+1;
          }
        });
        lab.currentStep = stepNumber;
        lab.totalSteps = _.size(lab.steps);
        var html = templates['templates/lab.hbs'](lab)
        this.$node.html(html);
        this.$node.find('.step').hide();
        this.$node.find('#step-'+stepNumber).show();
        this.$node.find('.step-title').hide();
        this.$node.find('.step-title.step-'+stepNumber).show();
        // we're extracting these and showing them separately,
        // so hide in the content
        this.$node.find('#lab-content .step h1').hide(); 

      }
      
      this.loadLabStep = function(evt, labId, stepNumber) {
        $('#vm-status').show();
        $('#lab-list-container').hide();
        $('.thumbnails li').removeClass('loading');
        $('#current-lab').show().html('loading...');
        $(document).trigger('loadLab', [labId, stepNumber]);
        $(window).scrollTop(0);
      }
      
      this.launchLabInstance = function(evt, lab) {
        if (this.currentLab !== lab) {
          if (!this.currentLab || alert("Are you sure you want to start a new lab?")) {
            
            if (this.currentLab) {
              $(document).trigger('terminateAllInstances');
            }
            
            this.currentLab = lab;
            $(document).trigger('launch', [lab.ami, lab.dataVolume, lab.name]);
            
          }
        }
      }
      
      this.after('initialize', function() {
        this.on('loadLabStep', this.loadLabStep);
        this.on(document, 'labLoaded', this.render);
        this.on(document, 'launchLabInstance', this.launchLabInstance);
        this.on(document, 'terminateInstance terminateAllInstances', function() { this.currentLab = null; });
      })
      
    }
  }
  
);
