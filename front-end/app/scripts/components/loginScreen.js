// TODO: prevent username/password from being displayed in the URL
// TODO: add fading animations back to alert box

define(
  [
    '../../components/flight/lib/component',
    'templates'
  ],

  function(defineComponent, templates) {
    
    
    return defineComponent(loginScreen);
    
    function loginScreen() {

      this.authenticate = function(username, password) {
        var creds = 'Basic ' + btoa(username + ':' + password);
        return $.ajax({
          type : 'POST',
          url : this.attr.launcherApi + '/session',
          dataType : 'json',
          beforeSend : function(xhr) {
            xhr.setRequestHeader('Authorization', creds);
          }
        });
      }

      this.setCreds = function(username, token) {
        $.cookie('username', username);
        $.cookie('sessionToken', token);
        this.$node.trigger('userChanged', username);
      }
      
      this.getCreds = function() {
        return {
          username : $.cookie('username'),
          sessionToken : $.cookie('sessionToken')
        };
      }
      
      this.logout = function() {
        creds = this.getCreds();
        $.ajax({
          type : 'DELETE',
          url : this.attr.launcherApi + '/session',
          xhrFields : {
            withCredentials : true
          }
        })
        this.setCreds(null, null);
      }
      
      this.requireLogin = function() {
        var creds = this.getCreds();
        console.log(creds);
        if (!creds['username'] || !creds['sessionToken']) {
          this.launch();
        } else {
          // trigger it anyway
          this.$node.trigger('userChanged', creds['username']);
        }
      }

      this.launch = function() {
        this.render();
        this.$node.find('#login-modal').modal({ keyboard: false, backdrop: 'static' });
      }

      this.alert = function(handle, title, message) {
        handle.find('h4').html(title);
        handle.find('p').html(message);
        handle.show(200);
      }

      this.render = function(evt, labList) {
        var html = templates['templates/loginScreen.hbs']({ labs : labList })
        this.$node.html(html);
        var component = this;
        
        var alertBox = this.$node.find('#alert-box');
        var alertBoxClose = alertBox.find('button[class=close]');
        alertBoxClose.click(function() {
          alertBox.hide(200);
        });

        this.$node.find('form').on('submit', function(e) {
          var username = $(this).find('input[name=username]').val();
          var password = $(this).find('input[name=password]').val();

          component.authenticate(username, password).done(function(data) {
            if('username' in data && 'sessionToken' in data) {
              // correct login
              component.setCreds(data['username'], data['sessionToken']);
              component.$node.find('#login-modal').modal('hide');
            } else {
              // unexpected server response
              console.log('>>> unexpected server response upon login:', data);
              component.alert(alertBox, 'Our Mistake', 'The server returned some unexpected gibberish. Please find a workshop admin.');
            }
          }).fail(function() {
            // incorrect login
            component.alert(alertBox, 'Oops?', 'Unfortunately that username/password combination is not in our records. Please try entering your username and password again.');
          });

          e.preventDefault();
        })
      }
      
      this.after('initialize', function() {
        this.on('requireLogin', this.requireLogin);
        this.on('logout', this.logout);
      })
      
    }
  }
  
);
