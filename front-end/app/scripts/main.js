require.config({
    paths: {
        jquery: '../components/jquery/jquery',
        'jquery.cookie': '../components/jquery.cookie/jquery.cookie',
        bootstrap: 'vendor/bootstrap',
        miso: 'vendor/miso.ds.deps.ie.0.4.1',
        handlebars: '../components/handlebars/handlebars',
        signals: '../components/js-signals/dist/signals',
        hashchange: 'vendor/jquery.ba-hashchange',
        term: 'vendor/term'
    },
    shim: {
        bootstrap: {
            deps: ['jquery'],
            exports: 'jquery'
        },
        'jquery.cookie': {
          deps: ['jquery'],
          exports: 'jquery'
        },
        miso: {
          exports: 'Miso'
        },
        handlebars: {
          exports: 'Handlebars'
        },
        term: {
            exports: 'Terminal'
        }
    }
});

require(['jquery'], function(app, $) {
        require(['app', 'bootstrap', 'jquery.cookie'], function(app, $) {
                'use strict';
        });
});
