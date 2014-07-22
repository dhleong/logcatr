'use strict'

Logcat = require 'adbkit-logcat'
Promise = require 'bluebird'
LineStream = require('byline').LineStream

### Controllers ###

angular.module('app.controllers', ['app.services'])

.controller('AppCtrl', [
  '$scope'
  '$location'
  '$resource'
  '$rootScope'

($scope, $location, $resource, $rootScope) ->

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

    devices.attach $scope

    deviceId = $routeParams.deviceId
    $scope.id = deviceId
    $scope.logcat = []
    $scope.deviceAvailable = false

    restartLogcat = ->
        # open logcat with the device
        adb.openLogcat(deviceId)
        .then (logcat) ->
            $scope._logcat = logcat

            logcat.includeAll Logcat.Priority.VERBOSE

            lastTimeout = -1
            logcat.on 'entry', (entry) ->
                # console.log 'entry', entry
                $scope.logcat.unshift entry
                clearTimeout lastTimeout
                lastTimeout = setTimeout ->
                    $scope.$apply()
                , 10
            logcat.on 'end', ->
                console.log 'stream ends!'

            logcat.on 'error', (err) ->
                console.log err

        .catch ->
            $scope.deviceAvailable = false
            $scope.$apply()


    $scope.$on 'devices', (ev, devices) ->
        wasAvailable = $scope.deviceAvailable
        $scope.deviceAvailable = _.findWhere(devices, id: deviceId)?
        console.log deviceId, 'vs', devices
        console.log 'deviceAvailable?', $scope.deviceAvailable, 'was=', wasAvailable

        if not wasAvailable and $scope.deviceAvailable
            # wasn't available, but is now
            $scope.logcat = []
            restartLogcat()

    $scope.$on '$destroy', ->
        $scope?._logcat?.end()
])
