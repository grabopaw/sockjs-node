events = require('events')
webjs = require('./webjs')
$ = require('jquery');

trans_websocket = require('./trans-websocket');
trans_jsonp = require('./trans-jsonp');


app =
    welcome_screen: (req, res) ->
        res.writeHead(200, {})
        res.end("Welcome to SockJS!")
        return true

$.extend(app, webjs.generic_app)
$.extend(app, trans_websocket.app)
$.extend(app, trans_jsonp.app)


class Server extends events.EventEmitter
    constructor: (user_options) ->
        @options =
            prefix: ''
            origins: ['*:*']
        if user_options
            $.extend(@options, user_options)

    installHandlers: (http_server, user_options) ->
        options = {}
        $.extend(options, @options)
        if user_options
            $.extend(options, user_options)

        p = (s) => new RegExp('^' + options.prefix + s + '[/]?$')
        t = (s) => [p('/([^/.]+)/([^/.]+)' + s), 'server', 'session']
        dispatcher = [
            ['GET', p(''), ['welcome_screen']],
            ['GET', t('/websocket'), ['websocket']],
            ['GET', t('/jsonp'), ['h_no_cache','jsonp']],
            ['POST', t('/send'), ['expect', 'jsonp_send', 'expose']],
        ]
        webjs_handler = new webjs.WebJS(app, dispatcher)

        install_handler = (ee, event, handler) ->
            old_listeners = ee.listeners(event)
            ee.removeAllListeners(event)
            new_handler = (a,b,c) ->
                if handler(a,b,c) isnt true
                    for listener in old_listeners
                        listener.call(this, a, b, c)
                return false
            ee.addListener(event, new_handler)
        handler = (req,res,extra) =>
            req.sockjs_server = @
            return webjs_handler.handler(req, res, extra)
        install_handler(http_server, 'request', handler)
        install_handler(http_server, 'upgrade', handler)
        return true

exports.Server = Server