define(
  [
    '../../components/flight/lib/component',
    'miso'
  ],

  function(defineComponent) {
    
    return defineComponent(dataLoader);
    
    function dataLoader() {
      
      this.LAB_SPREADSHEET_KEY = "0ArUwpx22UywjdGE3enQ4c3dtUERkZXBKTGNoRmhyclE";

      this.labs = [];
      this.labsById = {};
      this.dataCache = {};
      
      this.fetchSpreadsheet = function(key, callback) {
        var component = this;
        if (this.dataCache[key]) {
          callback(this.dataCache[key]);
        } else {
          var ds = new Miso.Dataset({
            url: "https://docs.google.com/spreadsheet/pub?key="+key+"&output=csv",
            delimiter: ","
          });
          ds.fetch({ 
            success : function() {
              component.dataCache[key] = ds;
              callback(ds);
            },
            error : function() {
              console.log("Are you sure you are connected to the internet?");
            }
          });          
        }
        
      }
      
      this.fetchDoc = function(key, callback) {
        var component = this;
        if (this.dataCache[key]) {
          callback(this.dataCache[key]);
        } else {
          $.ajax({
            url : 'https://docs.google.com/feeds/download/documents/export/Export?id=' + key + '&exportFormat=html'
          }).done(function(data) {
            component.dataCache[key] = data;
            callback(data);
          })
        }
      }
      
      this.loadLabList = function() {
        var component = this;
        
        this.fetchSpreadsheet(this.LAB_SPREADSHEET_KEY, function(ds) {
          this.labs = ds.rows().toJSON();
          // add slug ids
          _.each(this.labs, function(lab) {
            lab.id = lab.name.toLowerCase().replace(/\W/g,'-');
            component.labsById[lab.id] = lab;
          })

          component.trigger('labListLoaded', [this.labs]);          
        })

      }
      
      this.loadLab = function(evt, labId, step) {
        var lab = this.labsById[labId];
        var component = this;
        
        if (lab.spreadsheetKey) {
          // fetch the spreadsheet rows as lab steps
          this.fetchSpreadsheet(lab.spreadsheetKey, function(ds) {
            lab.steps = ds.rows().toJSON();
            _.each(lab.steps, function(step, i) { step.index = i+1 });
            component.trigger('labLoaded', [lab, step]);
          })          
        } else if (lab.docKey) {
          // fetch a google doc and split on page breaks
          this.fetchDoc(lab.docKey, function(data) {
            // just get the body, no styles
            var body = "";
            var docDom = $(data).each(function(i, el) { 
              if (!el.nodeName.match(/title|style/i)) {
                body += el.outerHTML;
              } else if (el.nodeName.match(/style/i)) {
                var styles = el.outerHTML;
                // scope the doc styles with our instruction selector
                var scopedStyles = styles.replace(/(>|})([^{]+){/g, "$1 #current-lab $2 {");
                body += scopedStyles;
              }
            });
            // split on page breaks
            var rawSteps = body.split('<hr style="page-break-before:always;display:none;">');
            lab.steps = _.map(rawSteps, function(step, i) { 
              var $step = $('<div>'+step+'</div>');
              // see if we have an h1 in the content, use that as the step title
              var $title = $($step.find('h1')[0]);
              var stepTitle = $title.length > 0 ? $title.text() : 'Step ' + (i+1);
              return { index: i+1, stepNumber: stepTitle, content : step }
            });
            component.trigger('labLoaded', [lab, step]);
          })
        }
        
      }
      
      this.after('initialize', function() {
        this.on('loadLabList', this.loadLabList);
        this.on('loadLab', this.loadLab);
      });
      
    }
    
  }
);