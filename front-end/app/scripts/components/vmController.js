define(
  [
    '../../components/flight/lib/component'
  ],

  function(defineComponent) {
    
    var component;
    
    return defineComponent(vmController);
    
    function vmController() {
      
      var component = this;
      
      this.username;
      
      this.listenForChanges = function() {
        var wsUrl = this.attr.launcherApi.replace('http','ws') + '/users/'+this.username+'/socket';
        console.log("listening for changes on " + wsUrl);
        var socket = new WebSocket(wsUrl);
        this.socket = socket;
        // right now, just treat this as a ping and reload all info
        socket.onmessage = this.loadInstances;
      }
      
      this.stopListening = function() {
        this.socket.close();
      }
      
      this.api = function(path, method, payload) {
        return $.ajax({
          url : this.attr.launcherApi + path,
          dataType : 'json',
          type : method || 'GET',
          data : JSON.stringify(payload),
          xhrFields : {
            withCredentials : true
          }
        }).fail(function(xhr, message) {
          if(xhr.status === 401) {
            $(component.attr.loginSelector).trigger('logout');
          } else {
            console.log('unexpected HTTP failure:', message);
          }
        });
      }
      
      this.launch = function(evt, ami, dataSnapshot, name) {
        console.log("launching", ami, dataSnapshot, name);
        this.api('/users/'+this.username+'/instances', 'POST', {
          ami : ami,
          // instance_type : 't1.micro',
          // instance_type: 'm1.medium',
          // instance_type: 'm1.large',
          instance_type: 'c1.xlarge',
          name : name,
          volume_snapshots : [dataSnapshot]
        });
      }
      
      this.loadInstances = function() {
        component.api('/users/'+component.username+'/instances').done(function(data) {
          this.instances = data.instances;
          component.$node.trigger('loadedInstances', [data.instances]);
        })
      }
      
      this.terminateInstance = function(evt, id) {
        console.log("terminating", id, "for user", this.username);
        component.api('/users/'+this.username+'/instances/'+id, 'DELETE');
      }
      
      this.terminateAllInstances = function(evt) {
        _.each(this.instances, function(instance) {
          this.terminateInstance(evt, instance.id);
        })
      }
      
      this.after('initialize', function() {
        
        component = this;
        
        console.log("talking to api at " + this.attr.launcherApi);
        
        this.on('loadInstances', this.loadInstances);
        this.on('launch', this.launch);
        this.on('terminateInstance', this.terminateInstance);
        this.on('terminateAllInstances', this.terminateAllInstances);
        
        this.on(this.attr.loginSelector, 'userChanged', function(evt, username) {
          this.username = username;
          if (username) {
            this.listenForChanges();
            this.loadInstances();
          } else {
            this.stopListening();
          }
        });
        
        
      });
      
    }
  }
  
);
