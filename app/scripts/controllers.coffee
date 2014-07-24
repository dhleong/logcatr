'use strict'

{spawn} = require 'child_process'
Logcat = require 'adbkit-logcat'
Promise = require 'bluebird'
LineStream = require('byline').LineStream

MAX_APPLY_CLEAR = 1000
MAX_SCROLLBACK = 1000

### Controllers ###

angular.module('app.controllers', ['app.services'])

.controller('AppCtrl', [
  '$window'
  '$timeout'
  '$scope'
  '$location'
  'adbClient'
  'devices'

($window, $timeout, $scope, $location, adb, devices) ->

    # Uses the url to determine if the selected
    # menu item should have the class active.
    $scope.$location = $location
    $scope.$watch('$location.path()', (path) ->
        $scope.activeNavId = path || '/'
    )

    # getClass compares the current url with the id.
    # If the current url starts with the id it returns 'active'
    # otherwise it will return '' an empty string. E.g.
    #
    #   # current url = '/products/1'
    #   getClass('/products') # returns 'active'
    #   getClass('/orders') # returns ''
    #
    $scope.getClass = (id) ->
        # if $scope.activeNavId.substring(0, id.length) == id
        if $scope.activeNavId is id
            return 'active'
        else
            return ''

    $scope.installApk = ->
        alert "Soon. Soon."

    $scope.restartAdb = ->

        $scope.restarting = true
        console.log 'killing server...'
        adb.kill()
        .then ->
            console.log 'killed server...'
            adb.listDevices()

        .then ->
            console.log 'Restarted successfully!'
            devices.restart()

        .catch (err) ->
            console.error err
            alert "Unable to kill adb server...\n#{err}"

        .finally ->
            $scope.restarting = false

    # drag-and-drop APK install
    $scope.dropping = no
    $window.ondragover = (e) -> e.preventDefault()
    $window.ondrop = (e) -> e.preventDefault()

    # little dance to update angular state without jank
    dropper = $('.dropper')
    dropper.on 'dragover', ->
        $timeout.cancel $scope.leaveTimeout
        $timeout -> $scope.dropping = yes
    dropper.on 'dragleave', -> $scope.leaveTimeout = $timeout -> $scope.dropping = no
    dropper.on 'dragend', -> $timeout -> $scope.dropping = no
    dropper.on 'drop', (e) ->
        $timeout -> $scope.dropping = no
        e.preventDefault()

        data = e.originalEvent.dataTransfer
        console.log 'drop!', file.path for file in data.files

])

.controller('DevicesController', [
    '$scope'
    'devices'

($scope, devices) ->
    devices.attach $scope
])

.controller('DeviceController', [
    '$scope'
    '$routeParams'
    '$timeout'
    'adbClient'
    'devices'

($scope, $routeParams, $timeout, adb, devices) ->

    deviceId = $routeParams.deviceId
    $scope.id = deviceId
    $scope.logcat = []
    $scope.completeLogcat = []
    $scope.deviceAvailable = false
    $scope.lastApply = new Date().getTime()
    $scope.filter = ''

    compileFilter = (raw) ->
        cleaned = raw.replace(/tag:\w+\|?/g, '')
        regex: if cleaned then new RegExp(cleaned, 'i') else null
        tags: tag.replace(/tag:(\w+)\|?/, '$1') for tag in raw.match(/tag:\w+\|?/g) or []

    # when we update filter, re-draw logcat
    $scope.$watch 'filter', (newFilter) ->
        if newFilter == ''
            # don't bother evaluating... there's no filter.
            #  To make it feel faster, though, let's do it in chunks
            $scope.logcat = $scope.completeLogcat.slice(0, 10)
            $timeout ->
                $scope.logcat = $scope.completeLogcat.slice()
            return

        # pre-compile filter since we'll need it a lot
        filter = compileFilter newFilter
        console.log filter
        $scope.logcat = ( entry for entry in $scope.completeLogcat \
            when $scope.logcatFilter(entry, filter) )

    # filter method
    $scope.logcatFilter = (entry, filter=null) ->
        filter = compileFilter($scope.filter) if not filter
        if not filter.regex and not filter.tags
            return true # no filter at all

        if filter.regex and \
                (entry.tag.match(filter.regex) or entry.message.match(filter.regex))
            return true
        return filter.tags.some (tag) -> ~entry.tag.toLowerCase().indexOf(tag)

    restartLogcat = ->
        # open logcat with the device
        adb.openLogcat(deviceId)
        .then (logcat) ->
            $scope._logcat = logcat

            logcat.includeAll Logcat.Priority.VERBOSE

            lastTimeout = -1
            logcat.on 'entry', (entry) ->
                # console.log 'entry', entry
                displayed = $scope.logcatFilter entry
                $scope.completeLogcat.unshift entry
                if displayed
                    $scope.logcat.unshift entry

                while $scope.completeLogcat.length > MAX_SCROLLBACK
                    $scope.completeLogcat.pop()
                while $scope.logcat.length > MAX_SCROLLBACK
                    $scope.logcat.pop()

                if displayed
                    # now = new Date().getTime()
                    # if now - $scope.lastApply < MAX_APPLY_CLEAR
                    clearTimeout lastTimeout
                    lastTimeout = setTimeout ->
                        $scope.lastApply = new Date().getTime()
                        $scope.$apply()
                    , 50

            logcat.on 'error', (err) ->
                # catch the error to prevent rcashes
                console.log err

        .catch ->
            $scope.deviceAvailable = false
            $scope.$apply()


    $scope.$on 'devices', (ev, devices) ->
        wasAvailable = $scope.deviceAvailable
        $scope.device = _.findWhere(devices, id: deviceId)
        $scope.deviceAvailable = $scope.device?
        # console.log deviceId, 'vs', devices
        # console.log 'deviceAvailable?', $scope.deviceAvailable, 'was=', wasAvailable

        if not wasAvailable and $scope.deviceAvailable
            # wasn't available, but is now
            $scope.logcat = []
            restartLogcat()

    $scope.$on '$destroy', ->
        # clean up after ourselves
        console.log 'stop logcat stream'
        $scope._logcat?.end()

    # attach to the device manager service
    devices.attach $scope

])
