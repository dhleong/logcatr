'use strict'

adbkit = require 'adbkit'
ApkReader = require 'adbkit-apkreader'
Promise = require 'bluebird'
request = Promise.promisify require('request')
htmlparser = require 'htmlparser'
{select} = require 'soupselect'

### Sevices ###

angular.module('app.services', [])

.factory('version', -> "0.1")

.factory('server', -> 
    # TODO actual
    addr: -> '192.168.1.27:8001'
)

.factory('readableStatus', [
    'server'
(server) -> "Listening on <a href>#{server.addr()}</a>"

])

.factory('adbClient', -> adbkit.createClient())

.factory('devices', [
    '$window'
    '$timeout'
    'adbClient'
(services...) -> new DeviceManager(services...) 
])

.factory 'imageFetcher', -> new ImageFetcher

### Definitions ###

class DeviceManager

    # map of raw prop name to device obj field name
    @PROP_TO_FIELD =
        'ro.product.model': 'model'
        'ro.product.manufacturer': 'manufacturer'

    constructor: (@window, @timeout, @adb) ->
        @devices = []
        @attached = []
        @_tracker = null

        @restart()

    install: ($scope, apk) => @timeout =>
        if apk.substr(-3) != 'apk'
            alert "#{apk} is not an apk"
            return

        console.log 'install', apk
        manifest = ApkReader.readFile(apk).readManifestSync()
        if not manifest
            alert "#{apk} is not a valid apk"
            return

        $scope.installProgress =
            done: 0
            total: @devices.length
        $scope.installProgress.toCss = ->
            width: 100 * ($scope.installProgress.done / $scope.installProgress.total) + '%'
            'min-width': '65px'

        Promise.map @devices, (device) =>
            @adb.install(device.id, apk)
            .then =>
                launchers = manifest.application.launcherActivities
                if launchers
                    component = "#{manifest.package}/#{launchers[0].name}"
                    @adb.startActivity device.id,
                        component: component
            .catch (err) ->
                console.error err
            .finally => @timeout =>
                console.log 'installed (or failed)!'
                $scope.installProgress.done++

                if $scope.installProgress.done == $scope.installProgress.total
                    @timeout ->
                        # clear
                        $scope.installProgress = undefined
                        console.log 'install done!'
                    , 1000

    restart: =>
        @tracker?.end() # just in case we already have one, kill it

        console.log 'DeviceManager!'
        $(@window).unload =>
            # cleanup
            console.log 'root scope going down!'
            @_tracker?.end()

        # track devices
        @adb.trackDevices()
        .then (tracker) =>
            @_tracker = tracker
            tracker.on 'add', (device) =>
                console.log 'add', device
                @processNewDevice device if device.type is 'device'
            
            tracker.on 'change', (device) =>
                # new devices generally start as "offline" and
                #  change to "device" later
                console.log 'change!', device
                @processNewDevice device if device.type is 'device'

            tracker.on 'remove', (device) =>
                console.log 'remove', device
                @devices = @devices.filter (victim) -> device.id != victim.id
                @_dispatchApply()

        .catch (error) ->
            console.log error

    processNewDevice: (device) =>
        @adb.shell(device.id, 'cat /system/build.prop')
        .then (stream) =>
            # extract stream into the dict
            stream.pipe(new LineStream())
                .on 'data', (buf) =>
                    line = buf.toString 'UTF-8'
                    parts = line.split '='
                    if not parts
                        return

                    field = DeviceManager.PROP_TO_FIELD[parts[0]]
                    if field
                        device[field] = parts[1]

                .on 'end', =>
                    console.log 'newDevice', device
                    @devices.push device
                    @_dispatchApply()

    _dispatchApply: =>
        console.log 'dispatch$apply:', @attached, @devices
        for $scope in @attached
            @timeout => $scope.devices = @devices
            $scope.$emit 'devices', @devices

    attach: ($scope) =>
        ### Attach the scope to the manager 

        We will populate an array called 'devices' on the
        scope, and $apply() changes to the scope whenever
        the array changes
        ###
        @attached.push $scope
        console.log 'attach scope', @attached
        $scope.$on '$destroy', =>
            console.log 'old scope', @attached
            @attached = @attached.filter (victim) -> victim != $scope
            console.log 'new scope', @attached
        @_dispatchApply()

    byId: (deviceId) => _.findWhere @devices, id: deviceId

class ImageFetcher

    @URL = 'http://www.gsmarena.com/results.php3?sQuickSearch=no&sName='

    constructor: ->
        @cache = {}
    
    fetch: (device) =>
        query = "#{device.manufacturer} #{device.model}"
        return Promise.resolve(@cache[query]) if @cache[query]

        url = ImageFetcher.URL + query.replace(/\W/g, '+')
        request(url).then (raw) =>
            [result, contents] = raw
            if result.statusCode is not 200
                throw new Error 'No device'
            return contents

        .then (contents) => new Promise (resolve, reject) =>
            # convert contents into a DOM
            handler = new htmlparser.DefaultHandler (err, dom) ->
                reject err if err?
                resolve dom
            new htmlparser.Parser(handler)
            .parseComplete contents

        .then (dom) =>
            [imgEl] = select(dom, '.makers ul li a img')
            src = imgEl?.attribs?.src?.replace 'thumb', 'bigpic'
            if src?
                # cache for later
                @cache[query] = src
                return src

            return null
