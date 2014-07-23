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
  '$scope'
  '$location'
  '$resource'
  '$rootScope'
  'adbClient'
  'devices'

($scope, $location, $resource, $rootScope, adb, devices) ->

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
    'adbClient'
    'devices'

($scope, $routeParams, adb, devices) ->

    deviceId = $routeParams.deviceId
    $scope.id = deviceId
    $scope.logcat = []
    $scope.completeLogcat = []
    $scope.deviceAvailable = false
    $scope.lastApply = new Date().getTime()
    $scope.logcatFilter = (entry) -> ~entry.tag.indexOf("minus")

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
