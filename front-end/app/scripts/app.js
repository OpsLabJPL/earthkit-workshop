/*global define */
define(
    [
      'components/dataLoader',
      'components/labPicker',
      'components/router',
      'components/labView',
      'components/loginScreen',
      'components/header',
      'components/vmToolbar',
      'components/vmController',
      'components/tty',
    ],

    function(DataLoader, LabPicker, Router, LabView, LoginScreen, Header, VMToolbar, VMController, TTY) {
    'use strict';

    var loginSelector = '#login-screen';
    var launcherApi = 'https://localhost:4567';
    
    DataLoader.attachTo(document);
    Header.attachTo('#header', { loginSelector : loginSelector });
    LabPicker.attachTo('#lab-list-container');
    LabView.attachTo('#current-lab');
    LoginScreen.attachTo(loginSelector, { launcherApi : launcherApi });
    VMToolbar.attachTo('#vm-toolbar', { loginSelector : loginSelector });
    VMController.attachTo(document, { launcherApi : launcherApi, loginSelector : loginSelector });
    TTY.attachTo('#console');

    var $loginEl = $(loginSelector);
    $loginEl.trigger('requireLogin');

    // if they log out, force login
    $loginEl.on('userChanged', function(evt, username) {
      if (!username) {
        $loginEl.trigger('requireLogin');
      }
    });

    // when a machine's ready, launch the console
    $(document).on('loadedInstances', function(evt, instances) {
      console.log("checking instances for console readiness");
      var instance = instances[0];
      if (instance) {
        if (instance.ready) {
          var ttyHost = "http://"+instance.hostname+":8080";
          console.log("opening terminal to " + ttyHost);
          $('#console').html("Waiting for connection...").trigger('openSession', [ttyHost, '#console']);
        } else if (instance.stopping) {
          $('#console').html("Console will activate when the instance is ready. You can launch the instance again when it is stopped.");
          console.log("VISIBLE?!", $('#lab-list-container:visible'));
          if($('#lab-list-container:visible').length < 1) {
            $('#console').show();
          }
        } else {
          $('#console').html("Console will activate when the instance is ready. Currently " + instance.status + ".");
          console.log("VISIBLE?!", $('#lab-list-container:visible'));
          if($('#lab-list-container:visible').length < 1) {
            $('#console').show();
          }
        }
      } else {
        $('#console').html("Console will activate when a virtual machine instance is running. Click the 'Launch' button to launch an instance.");
      }
    });

    $(document).on('terminateInstance terminateAllInstances', function() {
      $('#console').trigger('close');
    })

    $(document).trigger('loadLabList');

    $(document).on('labListLoaded', function(evt, labs) {
      Router.attachTo(document);
    });

});