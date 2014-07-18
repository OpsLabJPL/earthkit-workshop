define(
  [
    '../../components/flight/lib/component',
    'term'
  ],

  function(defineComponent) {

    return defineComponent(tty);

    function tty() {

      var component;

      this.terms = {}
      this.sockets = {}

      this.getNumRowsCols = function() {
            var widthElem = $('#monospace-width-model');
            var heightElem = $('#monospace-height-model');
            var rows = parseInt(8 * (this.$node.height()) / heightElem.height());
            var cols = parseInt(Math.min(80, 8 * (this.$node.width() - 30) / widthElem.width()));
            return [rows, cols];
      }

      this.closeSessions = function() {
        console.log("closing terminal sessions");
        _.each(component.terms, function(term, host) {
          term.destroy();
          delete component.terms[host];
          component.$node.html("");
          component.sockets[host].disconnect();
          delete component.sockets[host];
        });
      }

      this.openSession = function(evt, host, targetElement) {

        var setupTerm = function() {

          if (!component.terms[host]) {
            Terminal.options = {
            }

            var ttySize = component.getNumRowsCols();
            var rows = ttySize[0];
            var cols = ttySize[1];

            var term = new Terminal(cols, rows), socket = io.connect(host);
            component.terms[host] = term;
            component.sockets[host] = socket;

            term.cursorHidden = false;

            socket.on('connect', function() {
              term.on('data', function(data) {
                socket.emit('data', data);
              });

              term.open();

              // put it in the right div
              var termDiv = $('.terminal').detach();
              var parent = $(targetElement);
              parent.html(termDiv);

              parent.append(
                '<div class="alert alert-info" id="terminal-focus-alert" style="position:absolute; bottom:1em; left:1em; right:1em; display:none;">' +
                  '<h4 class="alert-heading" style="text-align: center;">Terminal Lost Keyboard Focus</h4>' +
                  '<p style="text-align:center;">Click within the terminal area to continue entering commands.</p>' +
                '</div>'
              );
              var focusPopupDiv = $('#terminal-focus-alert');

              socket.on('data', function(data) {
                term.write(data);
              });

              // clicking outside the terminal area will force it to give up focus
              parent.click(function(ev) {
                focusPopupDiv.hide(200);
                term.focus();
                ev.stopPropagation();
              });
              $('html').click(function(ev) {
                focusPopupDiv.show(200);
                term.unfocus();
              });

              // remove text edit focus when user is typing because the
              // content-editable cursor is distracting
              if($.browser.mozilla) {
                // more extensive content-editable handling for firefox because
                // it keeps spell checking everything...
                parent.mousemove(function(ev) {
                  parent.attr('contenteditable', 'true');
                });
                parent.keydown(function(ev) {
                  parent.attr('contenteditable', 'false');
                  parent.blur();
                });
              }
              else {
                parent.keydown(function(ev) {
                  parent.blur();
                });
              }

              term.write("Now connected. Type enter to continue. ");
            });

          }

        };

        var tries = 20;
        var loadSocket = function(fail, timeout) {
          if (tries > 0 && !component.terms[host]) {
          console.log("...fetching socket...");
            // we need to get the socket.io js file from that server, too
            $.getScript(host+'/socket.io/socket.io.js', setupTerm);
          tries++;
          setTimeout(function() { fail(fail, timeout) }, timeout);

        }
        }

        // keep trying until we connect
        // TODO give up after a certain number and/or when there's no running instance
        loadSocket(loadSocket, 5000);
      }

      this.after('initialize', function() {
        component = this;
        this.on('openSession', this.openSession);
        this.on('show', function() { component.$node.show(); });
        this.on('hide', function() { component.$node.hide(); });
        this.on('close', this.closeSessions);
        this.on(window, 'resize', function() {
          var ttySize = component.getNumRowsCols();
          var rows = ttySize[0];
          var cols = ttySize[1];
          for(var host in component.terms) {
            component.terms[host].resize(cols, rows);
          }
        });
        // open this by default (for testing)
        // $('#console').trigger('openSession', ['http://localhost:8080', '#console'])
      });
    }
  }
)